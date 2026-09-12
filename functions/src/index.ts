/* eslint-disable indent, require-jsdoc, valid-jsdoc */
import * as admin from "firebase-admin";
import {logger} from "firebase-functions";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import {defineSecret, defineString} from "firebase-functions/params";
import {onSchedule} from "firebase-functions/v2/scheduler";
import nodemailer from "nodemailer";
import {
  createHash,
  createHmac,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from "node:crypto";
// Financial callable implementations remain in source for the planned future
// release, but are intentionally not exported or deployed while the feature is
// dormant in the app.
export {
  notifyChurchWhenYouTubeLive,
  refreshKnownYouTubeBroadcasts,
  renewYouTubeChannelSubscriptions,
  syncYouTubeChannelSubscription,
  youtubeLiveWebhook,
} from "./youtube_live";
export {setFeedPostGlobal} from "./feed_global";
export {fanOutIdentityChanges} from "./identityFanout";
export {deleteAccount, deleteChurch, leaveChurch} from "./lifecycle";
export {generateVerseBackgroundImage} from "./verseImage";
export {summarizeBibleContent} from "./bibleSummary";
import {firestoreDatabaseIdParam, firestoreDb} from "./firestoreDb";

admin.initializeApp();

const smtpHost = defineString("SMTP_HOST");
const smtpPort = defineString("SMTP_PORT");
const smtpSecure = defineString("SMTP_SECURE");
const emailFrom = defineString("EMAIL_FROM");
const smtpUser = defineSecret("SMTP_USER");
const smtpPass = defineSecret("SMTP_PASS");
const passwordResetAppUrl =
  "https://flutterlearning-c9f6c.web.app/reset-password";
const passwordResetChallengeCollection = "passwordResetChallenges";
const passwordResetCodeLifetimeMs = 10 * 60 * 1000;
const passwordResetResendCooldownMs = 60 * 1000;
const passwordResetRequestWindowMs = 60 * 60 * 1000;
const passwordResetMaxRequestsPerWindow = 5;
const passwordResetMaxAttempts = 5;
const emailVerificationChallengeCollection = "emailVerificationChallenges";
const emailVerificationCodeLifetimeMs = 10 * 60 * 1000;
const emailVerificationResendCooldownMs = 60 * 1000;
const emailVerificationRequestWindowMs = 60 * 60 * 1000;
const emailVerificationMaxRequestsPerWindow = 5;
const emailVerificationMaxAttempts = 5;

type MailJobData = {
  kind?: string;
  template?: string;
  to?: string[] | string;
  subject?: string;
  text?: string;
  html?: string;
  data?: Record<string, unknown>;
  status?: string;
};

type TopicNotificationPayload = {
  title: string;
  body: string;
  topic: string;
  data?: Record<string, string>;
};

type FeedPostNotificationPayload = {
  churchId: string;
  feedId: string;
  authorId: string;
  authorTitle: string;
  authorBody: string;
  memberTitle: string;
  memberBody: string;
};

type DashboardPreviewMemberPayload = {
  uid: string;
  name: string;
  secondary: string;
  approved: boolean;
};

type DashboardMetricBucketPayload = {
  id: string;
  label: string;
  count: number;
  previewMembers: DashboardPreviewMemberPayload[];
};

type DashboardFamilyBucketPayload = {
  id: string;
  label: string;
  count: number;
  familyIds: string[];
};

type RecurringEventData = {
  isRecurring?: boolean;
  active?: boolean;
  startAt?: admin.firestore.Timestamp;
  recurrenceFrequency?: string;
  recurrenceIntervalWeeks?: number;
  recurrenceTimeZone?: string;
};

const recurringEventTimeZone = "Asia/Kolkata";

export const sendQueuedSuperAdminMail = onDocumentCreated(
  {
    document: "mail/{mailId}",
    region: "us-central1",
    secrets: [smtpUser, smtpPass],
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("Mail trigger fired without snapshot data.");
      return;
    }

    const job = snapshot.data() as MailJobData;
    if (job.kind !== "super_admin_notification") {
      logger.debug("Skipping non super admin mail job.", {
        mailId: snapshot.id,
        kind: job.kind ?? null,
      });
      return;
    }

    const recipients = normalizeRecipients(job.to);
    if (recipients.length === 0) {
      await snapshot.ref.update({
        status: "skipped",
        error: "missing-recipients",
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const resolvedSubject = resolveSubject(job);
    const resolvedText = resolveText(job);
    const resolvedHtml = (job.html ?? "").trim() || textToHtml(resolvedText);

    if (resolvedSubject.length === 0 || resolvedText.length === 0) {
      await snapshot.ref.update({
        status: "failed",
        error: "missing-message-content",
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    try {
      const transporter = nodemailer.createTransport({
        host: smtpHost.value(),
        port: Number.parseInt(smtpPort.value() || "587", 10),
        secure: (smtpSecure.value() || "false").toLowerCase() == "true",
        auth: {
          user: smtpUser.value(),
          pass: smtpPass.value(),
        },
      });

      await transporter.sendMail({
        from: emailFrom.value(),
        to: recipients,
        subject: resolvedSubject,
        text: resolvedText,
        html: resolvedHtml,
      });

      await snapshot.ref.update({
        status: "sent",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: admin.firestore.FieldValue.delete(),
      });
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Unknown mail error";

      logger.error("Failed to send super admin email.", {
        mailId: snapshot.id,
        error: message,
      });

      await snapshot.ref.update({
        status: "failed",
        error: message,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  },
);

export const queuePublicChurchRegistrationWelcome = onDocumentCreated(
  {
    document: "churches/{churchId}",
    region: "us-central1",
  },
  async (event) => {
    const churchSnapshot = event.data;
    if (!churchSnapshot) {
      logger.warn("Church registration trigger fired without snapshot data.");
      return;
    }

    const church = churchSnapshot.data();
    if (readUnknownString(church.registrationSource) !== "public") {
      return;
    }

    const churchId = event.params.churchId;
    const churchName =
      readUnknownString(church.name) || "Your church";
    const churchEmail = normalizeEmail(
      readUnknownString(church.email),
    );
    const configSnapshot = await churchSnapshot.ref
      .collection("config")
      .doc("app")
      .get();
    const adminEmails = normalizeRecipients(
      configSnapshot.data()?.admins as string[] | string | undefined,
    );
    const recipients = normalizeRecipients([
      churchEmail,
      ...adminEmails,
    ]);

    if (recipients.length === 0) {
      logger.warn("Public church registration has no welcome recipients.", {
        churchId,
      });
      return;
    }

    const superAdminsSnapshot = await admin.firestore()
      .collection("superAdmins")
      .where("enabled", "==", true)
      .limit(10)
      .get();
    const supportContacts = [
      ...new Set(
        superAdminsSnapshot.docs.flatMap((doc) => {
          const data = doc.data();
          const supportEmail = normalizeEmail(
            readUnknownString(data.supportEmail) ||
              readUnknownString(data.email),
          );
          const supportPhone =
            readUnknownString(data.supportPhone) ||
            readUnknownString(data.phone) ||
            readUnknownString(data.contact);
          return [supportEmail, supportPhone].filter(
            (value) => value.length > 0,
          );
        }),
      ),
    ];
    const supportLines = supportContacts.length > 0 ?
      [
        "Super admin support:",
        ...supportContacts.map((contact) => `• ${contact}`),
      ] :
      [
        "For support, contact the super admin team through the app.",
      ];
    const text = [
      "Welcome!",
      "",
      `We received the registration for "${churchName}".`,
      `Church ID: ${churchId}`,
      "",
      "Your registration is pending super admin approval.",
      "The church will remain hidden until the review is complete. " +
        "We will notify you when it is approved.",
      "",
      ...supportLines,
      "",
      "Thank you for joining our church community.",
    ].join("\n");

    await admin.firestore()
      .collection("mail")
      .doc(`public-registration-${churchId}`)
      .set({
        kind: "super_admin_notification",
        template: "church_registration_pending",
        to: recipients,
        subject: `Welcome - ${churchName} registration received`,
        text,
        html: textToHtml(text),
        data: {
          churchId,
          churchName,
          approvalStatus: "pending",
          supportContacts,
        },
        status: "queued",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  },
);

export const sendPasswordResetSmtpEmail = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [smtpUser, smtpPass],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({error: "method-not-allowed"});
      return;
    }

    const email = normalizeEmail(String(req.body?.email ?? ""));
    const churchName = readUnknownString(req.body?.churchName) || "Church App";
    const mode = readUnknownString(req.body?.mode) || "reset";

    if (email.length === 0 || !email.includes("@")) {
      res.status(400).json({error: "invalid-email"});
      return;
    }

    try {
      const resetLink = await admin.auth().generatePasswordResetLink(email);
      const appResetLink = buildAppPasswordResetLink({
        firebaseResetLink: resetLink,
        email,
        churchName,
      });
      const subject = mode == "setup" ?
        `Set up your ${churchName} password` :
        `Reset your ${churchName} password`;
      const text = mode == "setup" ?
        [
          "Hello,",
          "",
          `Your account for ${churchName} is ready.`,
          "Use the link below to set your password and complete setup:",
          appResetLink,
          "",
          "If you were not expecting this email, you can ignore it.",
        ].join("\n") :
        [
          "Hello,",
          "",
          `We received a request to reset your password for ${churchName}.`,
          "Use the link below to choose a new password:",
          appResetLink,
          "",
          "If you did not request this, you can safely ignore this email.",
        ].join("\n");

      await createTransporter().sendMail({
        from: emailFrom.value(),
        to: [email],
        subject,
        text,
        html: textToHtml(text),
      });

      res.status(200).json({success: true});
    } catch (error) {
      const authError = error as {code?: string; message?: string};
      if (authError.code === "auth/user-not-found") {
        res.status(200).json({success: true});
        return;
      }

      logger.error("Failed to send password reset email.", {
        email,
        error: authError.message ?? String(error),
      });
      res.status(500).json({error: "reset-email-failed"});
    }
  },
);

export const requestPasswordResetCode = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [smtpUser, smtpPass],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({error: "method-not-allowed"});
      return;
    }

    const email = normalizeEmail(String(req.body?.email ?? ""));
    const churchName = readUnknownString(req.body?.churchName) || "Church App";
    if (email.length === 0 || !email.includes("@")) {
      res.status(400).json({error: "invalid-email"});
      return;
    }

    let user: admin.auth.UserRecord;
    try {
      user = await admin.auth().getUserByEmail(email);
    } catch (error) {
      const authError = error as {code?: string};
      if (authError.code === "auth/user-not-found") {
        res.status(200).json({success: true});
        return;
      }
      logger.error("Unable to look up password reset user.", {
        error: String(error),
      });
      res.status(500).json({error: "reset-code-failed"});
      return;
    }

    const now = Date.now();
    const challengeId = passwordResetChallengeId(email);
    const challengeRef = admin.firestore()
      .collection(passwordResetChallengeCollection)
      .doc(challengeId);
    const code = randomInt(0, 1000000).toString().padStart(6, "0");
    const codeHash = passwordResetCodeHash(challengeId, code);

    try {
      const shouldSend = await admin.firestore().runTransaction(
        async (transaction) => {
          const snapshot = await transaction.get(challengeRef);
          const current = snapshot.data();
          const lastSentAt = timestampMillis(current?.lastSentAt);
          const windowStartedAt = timestampMillis(current?.windowStartedAt);
          const inCurrentWindow =
            windowStartedAt > 0 && now - windowStartedAt <
              passwordResetRequestWindowMs;
          const requestCount = inCurrentWindow ?
            Number(current?.requestCount ?? 0) : 0;
          const deliveryStatus = readUnknownString(current?.deliveryStatus);

          if ((deliveryStatus === "active" || deliveryStatus === "pending") &&
              lastSentAt > 0 &&
              now - lastSentAt < passwordResetResendCooldownMs) {
            return false;
          }
          if (requestCount >= passwordResetMaxRequestsPerWindow) {
            return false;
          }

          transaction.set(challengeRef, {
            uid: user.uid,
            codeHash,
            expiresAt: admin.firestore.Timestamp.fromMillis(
              now + passwordResetCodeLifetimeMs,
            ),
            attemptsRemaining: passwordResetMaxAttempts,
            requestCount: requestCount + 1,
            windowStartedAt: admin.firestore.Timestamp.fromMillis(
              inCurrentWindow ? windowStartedAt : now,
            ),
            lastSentAt: admin.firestore.Timestamp.fromMillis(now),
            deliveryStatus: "pending",
            resetTokenHash: admin.firestore.FieldValue.delete(),
            resetTokenExpiresAt: admin.firestore.FieldValue.delete(),
            consumedAt: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
          return true;
        },
      );

      if (!shouldSend) {
        res.status(200).json({success: true});
        return;
      }

      const text = [
        "Hello,",
        "",
        `We received a request to reset your password for ${churchName}.`,
        `Your verification code is: ${code}`,
        "",
        "This code expires in 10 minutes.",
        "If you did not request this, you can safely ignore this email.",
      ].join("\n");
      await createTransporter().sendMail({
        from: emailFrom.value(),
        to: [email],
        subject: `Your ${churchName} password reset code`,
        text,
        html: textToHtml(text),
      });
      await challengeRef.update({
        deliveryStatus: "active",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(200).json({success: true});
    } catch (error) {
      logger.error("Failed to send password reset code.", {
        error: String(error),
      });
      await challengeRef.update({deliveryStatus: "failed"}).catch(() => null);
      res.status(500).json({error: "reset-code-failed"});
    }
  },
);

export const verifyPasswordResetCode = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [smtpPass],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({error: "method-not-allowed"});
      return;
    }

    const email = normalizeEmail(String(req.body?.email ?? ""));
    const code = readUnknownString(req.body?.code);
    if (email.length === 0 || !/^\d{6}$/.test(code)) {
      res.status(400).json({error: "invalid-code"});
      return;
    }

    const now = Date.now();
    const challengeId = passwordResetChallengeId(email);
    const challengeRef = admin.firestore()
      .collection(passwordResetChallengeCollection)
      .doc(challengeId);
    const resetToken = randomBytes(32).toString("base64url");
    try {
      const verificationResult = await admin.firestore().runTransaction(
        async (transaction) => {
        const snapshot = await transaction.get(challengeRef);
        const data = snapshot.data();
        if (!snapshot.exists || data?.deliveryStatus !== "active") {
          return "invalid-code";
        }
        if (timestampMillis(data.expiresAt) <= now) {
          return "expired-code";
        }
        const attemptsRemaining = Number(data.attemptsRemaining ?? 0);
        if (attemptsRemaining <= 0) {
          return "too-many-attempts";
        }
        const expectedHash = readUnknownString(data.codeHash);
        const submittedHash = passwordResetCodeHash(challengeId, code);
        if (!secureStringEqual(expectedHash, submittedHash)) {
          transaction.update(challengeRef, {
            attemptsRemaining: attemptsRemaining - 1,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return attemptsRemaining - 1 <= 0 ?
            "too-many-attempts" : "invalid-code";
        }

        transaction.update(challengeRef, {
          codeHash: admin.firestore.FieldValue.delete(),
          resetTokenHash: sha256(resetToken),
          resetTokenExpiresAt: admin.firestore.Timestamp.fromMillis(
            now + passwordResetCodeLifetimeMs,
          ),
          verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return "verified";
      });
      if (verificationResult !== "verified") {
        res.status(verificationResult === "too-many-attempts" ? 429 : 400)
          .json({error: verificationResult});
        return;
      }
      res.status(200).json({success: true, resetToken});
    } catch (error) {
      const code = error instanceof Error ? error.message : "invalid-code";
      const allowed = new Set([
        "invalid-code",
        "expired-code",
        "too-many-attempts",
      ]);
      res.status(code === "too-many-attempts" ? 429 : 400).json({
        error: allowed.has(code) ? code : "invalid-code",
      });
    }
  },
);

export const completePasswordReset = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [smtpPass],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({error: "method-not-allowed"});
      return;
    }

    const email = normalizeEmail(String(req.body?.email ?? ""));
    const resetToken = readUnknownString(req.body?.resetToken);
    const newPassword = String(req.body?.newPassword ?? "");
    if (email.length === 0 || resetToken.length < 32) {
      res.status(400).json({error: "invalid-reset-session"});
      return;
    }
    if (newPassword.length < 8 ||
        !/[A-Z]/.test(newPassword) ||
        !/\d/.test(newPassword)) {
      res.status(400).json({error: "weak-password"});
      return;
    }

    const now = Date.now();
    const challengeRef = admin.firestore()
      .collection(passwordResetChallengeCollection)
      .doc(passwordResetChallengeId(email));
    let uid = "";
    try {
      await admin.firestore().runTransaction(async (transaction) => {
        const snapshot = await transaction.get(challengeRef);
        const data = snapshot.data();
        const storedTokenHash = readUnknownString(data?.resetTokenHash);
        if (!snapshot.exists ||
            storedTokenHash.length === 0 ||
            !secureStringEqual(storedTokenHash, sha256(resetToken)) ||
            timestampMillis(data?.resetTokenExpiresAt) <= now ||
            data?.consumedAt !== undefined) {
          throw new Error("invalid-reset-session");
        }
        uid = readUnknownString(data?.uid);
        if (uid.length === 0) throw new Error("invalid-reset-session");
        transaction.update(challengeRef, {
          consumedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await admin.auth().updateUser(uid, {password: newPassword});
      await admin.auth().revokeRefreshTokens(uid);
      await challengeRef.delete();
      res.status(200).json({success: true});
    } catch (error) {
      const code = error instanceof Error ?
        error.message : "password-reset-failed";
      if (uid.length > 0 && code !== "invalid-reset-session") {
        await challengeRef.update({
          consumedAt: admin.firestore.FieldValue.delete(),
        }).catch(() => null);
      }
      logger.error("Failed to complete password reset.", {
        code,
        uid: uid || null,
      });
      res.status(code === "invalid-reset-session" ? 400 : 500).json({
        error: code === "invalid-reset-session" ?
          code : "password-reset-failed",
      });
    }
  },
);

function emailVerificationChallengeId(uid: string): string {
  return createHmac("sha256", smtpPass.value())
    .update(uid)
    .digest("hex");
}

function emailVerificationCodeHash(challengeId: string, code: string): string {
  return createHmac("sha256", smtpPass.value())
    .update(`${challengeId}:${code}`)
    .digest("hex");
}

/**
 * Signup email-OTP (§5.5 addendum) — sends a 6-digit code to the caller's
 * own Firebase Auth email. Callable (not onRequest like password reset)
 * because the caller is already signed in by this point: the profile-setup
 * step has already created their `users/{uid}` doc, and this just gates
 * entry past it, so `request.auth` is the source of truth for which email
 * to use rather than trusting a client-supplied address.
 */
export const requestSignupEmailVerificationCode = onCall(
  {region: "us-central1", secrets: [smtpUser, smtpPass]},
  async (request) => {
    const uid = readUnknownString(request.auth?.uid);
    if (!uid) throw new HttpsError("unauthenticated", "Sign-in required.");

    const authUser = await admin.auth().getUser(uid);
    const email = normalizeEmail(authUser.email ?? "");
    if (email.length === 0) {
      throw new HttpsError("failed-precondition", "no-email");
    }
    const churchName = readUnknownString(request.data?.churchName) ||
      "Church App";

    const firestore = firestoreDb();
    const now = Date.now();
    const challengeId = emailVerificationChallengeId(uid);
    const challengeRef = firestore
      .collection(emailVerificationChallengeCollection)
      .doc(challengeId);
    const code = randomInt(0, 1000000).toString().padStart(6, "0");
    const codeHash = emailVerificationCodeHash(challengeId, code);

    const shouldSend = await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(challengeRef);
      const current = snapshot.data();
      const lastSentAt = timestampMillis(current?.lastSentAt);
      const windowStartedAt = timestampMillis(current?.windowStartedAt);
      const inCurrentWindow =
        windowStartedAt > 0 && now - windowStartedAt <
          emailVerificationRequestWindowMs;
      const requestCount = inCurrentWindow ?
        Number(current?.requestCount ?? 0) : 0;
      const deliveryStatus = readUnknownString(current?.deliveryStatus);

      if ((deliveryStatus === "active" || deliveryStatus === "pending") &&
          lastSentAt > 0 &&
          now - lastSentAt < emailVerificationResendCooldownMs) {
        return false;
      }
      if (requestCount >= emailVerificationMaxRequestsPerWindow) {
        return false;
      }

      transaction.set(challengeRef, {
        uid,
        email,
        codeHash,
        expiresAt: admin.firestore.Timestamp.fromMillis(
          now + emailVerificationCodeLifetimeMs,
        ),
        attemptsRemaining: emailVerificationMaxAttempts,
        requestCount: requestCount + 1,
        windowStartedAt: admin.firestore.Timestamp.fromMillis(
          inCurrentWindow ? windowStartedAt : now,
        ),
        lastSentAt: admin.firestore.Timestamp.fromMillis(now),
        deliveryStatus: "pending",
        verifiedAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      return true;
    });

    if (!shouldSend) return {success: true};

    try {
      const text = [
        "Hello,",
        "",
        `Your ${churchName} email verification code is: ${code}`,
        "",
        "This code expires in 10 minutes.",
        "If you did not request this, you can safely ignore this email.",
      ].join("\n");
      await createTransporter().sendMail({
        from: emailFrom.value(),
        to: [email],
        subject: `Your ${churchName} verification code`,
        text,
        html: textToHtml(text),
      });
      await challengeRef.update({
        deliveryStatus: "active",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return {success: true};
    } catch (error) {
      logger.error("Failed to send signup email verification code.", {
        uid,
        error: String(error),
      });
      await challengeRef.update({deliveryStatus: "failed"}).catch(() => null);
      throw new HttpsError("internal", "verification-code-failed");
    }
  },
);

/**
 * Verifies a signup email-OTP code and marks `users/{uid}.emailVerified`.
 * Callable so `request.auth.uid` — not a client-supplied uid — decides
 * whose challenge/identity doc is touched.
 */
export const verifySignupEmailVerificationCode = onCall(
  {region: "us-central1", secrets: [smtpPass]},
  async (request) => {
    const uid = readUnknownString(request.auth?.uid);
    if (!uid) throw new HttpsError("unauthenticated", "Sign-in required.");
    const code = readUnknownString(request.data?.code);
    if (!/^\d{6}$/.test(code)) {
      throw new HttpsError("invalid-argument", "invalid-code");
    }

    const firestore = firestoreDb();
    const now = Date.now();
    const challengeId = emailVerificationChallengeId(uid);
    const challengeRef = firestore
      .collection(emailVerificationChallengeCollection)
      .doc(challengeId);
    const userRef = firestore.collection("users").doc(uid);

    const result = await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(challengeRef);
      const data = snapshot.data();
      if (!snapshot.exists || data?.deliveryStatus !== "active") {
        return "invalid-code";
      }
      if (timestampMillis(data.expiresAt) <= now) return "expired-code";
      const attemptsRemaining = Number(data.attemptsRemaining ?? 0);
      if (attemptsRemaining <= 0) return "too-many-attempts";
      const expectedHash = readUnknownString(data.codeHash);
      const submittedHash = emailVerificationCodeHash(challengeId, code);
      if (!secureStringEqual(expectedHash, submittedHash)) {
        transaction.update(challengeRef, {
          attemptsRemaining: attemptsRemaining - 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return attemptsRemaining - 1 <= 0 ?
          "too-many-attempts" : "invalid-code";
      }

      transaction.update(challengeRef, {
        codeHash: admin.firestore.FieldValue.delete(),
        deliveryStatus: "verified",
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.set(userRef, {
        emailVerified: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      return "verified";
    });

    if (result !== "verified") {
      throw new HttpsError(
        result === "too-many-attempts" ? "resource-exhausted" :
          "invalid-argument",
        result,
      );
    }
    return {success: true};
  },
);

/**
 * Sends a topic notification through FCM.
 * @param payload Notification payload.
 * @return Promise that resolves when the notification is sent.
 */
async function sendTopicNotification(
  payload: TopicNotificationPayload,
): Promise<void> {
  await admin.messaging().send({
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: payload.data,
    topic: payload.topic,
  });
}

function notificationTopicSegment(value: string): string {
  return value.trim().replace(/[^a-zA-Z0-9\-_.~%]/g, "_");
}

function churchGroupTopic(churchId: string, groupId: string): string {
  return `church_${notificationTopicSegment(churchId)}_group_` +
    notificationTopicSegment(groupId);
}

function churchUserTopic(churchId: string, uid: string): string {
  return `church_${notificationTopicSegment(churchId)}_user_` +
    notificationTopicSegment(uid);
}

/**
 * Resolves every FCM token registered across every device
 * (`users/{uid}/devices/{installationId}`) for a set of person uids.
 * One person can have several devices, and their token set doesn't depend
 * on which church happens to be selected on any of them (§2.6/Phase 5) — a
 * post in church A must still reach a device currently sitting in church B.
 * @param uids The linked person uids to resolve devices for.
 * @return Map of uid -> that person's distinct fcm tokens.
 */
async function resolveDeviceTokensByUid(
  uids: string[],
): Promise<Map<string, string[]>> {
  const tokensByUid = new Map<string, string[]>();
  const distinctUids = Array.from(new Set(uids))
    .filter((uid) => uid.length > 0);
  if (distinctUids.length === 0) return tokensByUid;

  const chunkSize = 30; // Firestore "in" query limit.
  for (let index = 0; index < distinctUids.length; index += chunkSize) {
    const chunk = distinctUids.slice(index, index + chunkSize);
    const snapshot = await firestoreDb()
      .collectionGroup("devices")
      .where("uid", "in", chunk)
      .get();

    snapshot.docs.forEach((doc) => {
      const data = doc.data();
      const uid = readUnknownString(data["uid"]);
      const token = readUnknownString(data["fcmToken"]);
      if (!uid || !token) return;
      const existing = tokensByUid.get(uid) ?? [];
      if (!existing.includes(token)) existing.push(token);
      tokensByUid.set(uid, existing);
    });
  }

  return tokensByUid;
}

async function sendFeedPostNotification(
  payload: FeedPostNotificationPayload,
): Promise<number> {
  const membersSnapshot = await firestoreDb()
    .collection("churches")
    .doc(payload.churchId)
    .collection("members")
    .get();

  const linkedUids = membersSnapshot.docs
    .map((doc) => readUnknownString(doc.data()["linkedUid"]))
    .filter((uid) => uid.length > 0);
  const tokensByUid = await resolveDeviceTokensByUid(linkedUids);

  const messages: admin.messaging.Message[] = [];
  const seenTokens = new Set<string>();

  for (const uid of tokensByUid.keys()) {
    const isAuthor = uid === payload.authorId;
    for (const token of tokensByUid.get(uid) ?? []) {
      if (seenTokens.has(token)) continue;
      seenTokens.add(token);
      messages.push({
        token,
        notification: {
          title: isAuthor ? payload.authorTitle : payload.memberTitle,
          body: isAuthor ? payload.authorBody : payload.memberBody,
        },
        data: {
          kind: "feed_post_created",
          churchId: payload.churchId,
          feedId: payload.feedId,
          authorId: payload.authorId,
        },
      });
    }
  }

  let successCount = 0;
  for (let index = 0; index < messages.length; index += 500) {
    const batch = messages.slice(index, index + 500);
    const response = await admin.messaging().sendEach(batch);
    successCount += response.successCount;
  }

  return successCount;
}

async function sendPrayerRequestAdminNotification(
  churchId: string,
  prayerId: string,
): Promise<{successCount: number; failureCount: number}> {
  const firestore = firestoreDb();
  const churchRef = firestore.collection("churches").doc(churchId);
  const [configSnapshot, membersSnapshot] = await Promise.all([
    churchRef.collection("config").doc("app").get(),
    churchRef.collection("members").get(),
  ]);

  const rawAdmins = configSnapshot.data()?.admins;
  const adminEmails = new Set(
    (Array.isArray(rawAdmins) ? rawAdmins : [])
      .map((value) => readUnknownString(value).toLowerCase())
      .filter((email) => email.length > 0),
  );

  if (adminEmails.size === 0) {
    logger.warn("Prayer request notification has no configured admins.", {
      churchId,
      prayerId,
    });
    return {successCount: 0, failureCount: 0};
  }

  const adminLinkedUids = membersSnapshot.docs
    .filter((doc) => {
      const email = readUnknownString(doc.data()["displayEmail"]);
      return adminEmails.has(email.toLowerCase());
    })
    .map((doc) => readUnknownString(doc.data()["linkedUid"]))
    .filter((uid) => uid.length > 0);
  const tokensByUid = await resolveDeviceTokensByUid(adminLinkedUids);

  const messages: admin.messaging.Message[] = [];
  const seenTokens = new Set<string>();

  for (const tokens of tokensByUid.values()) {
    for (const token of tokens) {
      if (seenTokens.has(token)) continue;
      seenTokens.add(token);
      messages.push({
        token,
        notification: {
          title: "New prayer request",
          body: "A new prayer request was added to your church.",
        },
        data: {
          kind: "prayer_request_created",
          churchId,
          prayerId,
        },
      });
    }
  }

  let successCount = 0;
  let failureCount = 0;
  for (let index = 0; index < messages.length; index += 500) {
    const response = await admin.messaging().sendEach(
      messages.slice(index, index + 500),
    );
    successCount += response.successCount;
    failureCount += response.failureCount;
  }

  return {successCount, failureCount};
}

export const notifyChurchAdminsOnPrayerCreated = onDocumentCreated(
  {
    document: "churches/{churchId}/prayer_requests/{prayerId}",
    database: firestoreDatabaseIdParam,
    region: "us-central1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("Prayer request trigger fired without snapshot data.", {
        params: event.params,
      });
      return;
    }

    const churchId = readUnknownString(event.params.churchId);
    const prayerId = readUnknownString(event.params.prayerId);
    if (!churchId || !prayerId) {
      logger.warn("Prayer request trigger is missing path parameters.", {
        params: event.params,
      });
      return;
    }

    if (snapshot.data().visibleToChurchMembers === true) {
      logger.info(
        "Skipping separate admin push for a church-visible prayer request.",
        {churchId, prayerId},
      );
      return;
    }

    const result = await sendPrayerRequestAdminNotification(
      churchId,
      prayerId,
    );

    logger.info("Prayer request admin notifications processed.", {
      churchId,
      prayerId,
      ...result,
    });
  },
);

export const notifyChurchMembersOnArticleCreated = onDocumentCreated(
  {
    document: "churches/{churchId}/articles/{articleId}",
    region: "us-central1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("Article notification trigger has no snapshot data.", {
        params: event.params,
      });
      return;
    }

    const churchId = readUnknownString(event.params.churchId);
    const articleId = readUnknownString(event.params.articleId);
    if (!churchId || !articleId) {
      logger.warn("Article notification trigger is missing path parameters.", {
        params: event.params,
      });
      return;
    }

    const articleTitle = readUnknownString(snapshot.data().title);
    await sendTopicNotification({
      title: "New article",
      body: articleTitle ?
        `${articleTitle} is ready to read.` :
        "A new article is ready to read.",
      topic: `church_${churchId}`,
      data: {
        kind: "article_created",
        churchId,
        articleId,
      },
    });

    logger.info("New article notification sent to church members.", {
      churchId,
      articleId,
    });
  },
);

export const notifyCircleMembersOnResponseCreated = onDocumentCreated(
  {
    document:
      "churches/{churchId}/youth_circles/{circleId}/responses/{responseId}",
    region: "us-central1",
  },
  async (event) => {
    const responseSnapshot = event.data;
    if (!responseSnapshot) {
      logger.warn("Circle response trigger fired without snapshot data.", {
        params: event.params,
      });
      return;
    }

    const churchId = readUnknownString(event.params.churchId);
    const circleId = readUnknownString(event.params.circleId);
    const responseId = readUnknownString(event.params.responseId);
    const response = responseSnapshot.data();
    const authorId = readUnknownString(response.userId);
    const notificationBody = readUnknownString(response.notificationBody);
    if (!churchId || !circleId || !responseId || !authorId) {
      logger.warn("Circle response trigger is missing required data.", {
        churchId,
        circleId,
        responseId,
      });
      return;
    }

    const circleSnapshot = await admin.firestore()
      .collection("churches")
      .doc(churchId)
      .collection("youth_circles")
      .doc(circleId)
      .get();
    const circle = circleSnapshot.data();
    const groupId = readUnknownString(circle?.audienceGroupId);
    const circleTitle = readUnknownString(circle?.title);
    if (!circleSnapshot.exists || !groupId || !circleTitle) {
      logger.warn("Circle response notification has no valid audience.", {
        churchId,
        circleId,
        responseId,
      });
      return;
    }

    const groupTopic = churchGroupTopic(churchId, groupId);
    const authorTopic = churchUserTopic(churchId, authorId);
    await admin.messaging().send({
      notification: {
        title: circleTitle,
        body: notificationBody || "A new response was shared in your Circle.",
      },
      data: {
        kind: "circle_response_created",
        churchId,
        circleId,
        groupId,
      },
      condition: `'${groupTopic}' in topics && ` +
        `!('${authorTopic}' in topics)`,
    });

    logger.info("Circle response notification sent to its group.", {
      churchId,
      circleId,
      responseId,
      groupId,
      authorId,
    });
  },
);

export const notifyChurchMembersWhenPrayerVisible = onDocumentWritten(
  {
    document: "churches/{churchId}/prayer_requests/{prayerId}",
    region: "us-central1",
  },
  async (event) => {
    const beforeVisible =
      event.data?.before.exists &&
      event.data.before.data()?.visibleToChurchMembers === true;
    const afterVisible =
      event.data?.after.exists &&
      event.data.after.data()?.visibleToChurchMembers === true;

    if (beforeVisible || !afterVisible) return;

    const churchId = readUnknownString(event.params.churchId);
    const prayerId = readUnknownString(event.params.prayerId);
    if (!churchId || !prayerId) {
      logger.warn("Prayer visibility trigger is missing path parameters.", {
        params: event.params,
      });
      return;
    }

    await sendTopicNotification({
      title: "Pray for someone in your church",
      body: "A prayer request was shared. Join your church in prayer.",
      topic: `church_${churchId}`,
      data: {
        kind: "prayer_request_visible",
        churchId,
        prayerId,
      },
    });

    logger.info("Church-visible prayer notification sent.", {
      churchId,
      prayerId,
    });
  },
);

export const processQueuedChurchNotification = onDocumentCreated(
  {
    document: "churches/{churchId}/notification_requests/{notificationId}",
    database: firestoreDatabaseIdParam,
    region: "us-central1",
  },
  async (event) => {
    const snapshot = event.data;
    const data = snapshot?.data();

    if (!snapshot || !data) {
      logger.warn("Notification queue trigger fired without snapshot data.", {
        params: event.params,
      });
      return;
    }

    const title = readUnknownString(data.title);
    const body = readUnknownString(data.body);
    const topic = readUnknownString(data.topic);
    const kind = readUnknownString(data.kind);
    const feedId = readUnknownString(data.feedId);
    const authorId = readUnknownString(data.authorId);

    if (!title || !body || !topic) {
      await snapshot.ref.update({
        status: "failed",
        error: "Missing required notification fields",
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    try {
      const sentCount =
        kind == "feed_post_created" && authorId ?
          await sendFeedPostNotification({
            churchId: event.params.churchId,
            feedId: feedId || snapshot.id,
            authorId,
            authorTitle: "Your post is live",
            authorBody: "Your feed post was published successfully.",
            memberTitle: title,
            memberBody: body,
          }) :
          (await sendTopicNotification({
            title,
            body,
            topic,
            data: {
              ...(kind ? {kind} : {}),
              churchId: event.params.churchId,
            },
          }), null);

      await snapshot.ref.update({
        status: "sent",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(sentCount == null ? {} : {sentCount}),
        error: admin.firestore.FieldValue.delete(),
      });

      logger.info("Queued church notification sent.", {
        notificationId: snapshot.id,
        topic,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);

      logger.error("Error sending queued church notification.", {
        notificationId: snapshot.id,
        topic,
        error: message,
      });

      await snapshot.ref.update({
        status: "failed",
        error: message,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  },
);


export const rebuildChurchDashboardMemberMetrics = onDocumentWritten(
  {
    document: "churches/{churchId}/members/{uid}",
    database: firestoreDatabaseIdParam,
    region: "us-central1",
  },
  async (event) => {
    const churchId = readUnknownString(event.params.churchId);
    if (!churchId) {
      logger.warn("Dashboard metrics trigger missing churchId.", {
        params: event.params,
      });
      return;
    }

    try {
      const firestore = firestoreDb();
      const membersSnapshot = await firestore
        .collection("churches")
        .doc(churchId)
        .collection("members")
        .get();

      // dayStreak moved off the membership doc onto the person's identity
      // (users/{uid}) — one global streak per person (D4). Batch-fetch it
      // for every linked member so the per-church leaderboard still works.
      const linkedUids = membersSnapshot.docs
        .map((doc) => readUnknownString(doc.data()["linkedUid"]))
        .filter((uid): uid is string => uid.length > 0);
      const streakByUid = new Map<string, number>();
      if (linkedUids.length > 0) {
        const identityRefs = linkedUids.map((uid) =>
          firestore.collection("users").doc(uid));
        const identityDocs = await firestore.getAll(...identityRefs);
        identityDocs.forEach((doc, index) => {
          if (doc.exists) {
            streakByUid.set(
              linkedUids[index],
              readUnknownInteger(doc.data()?.["dayStreak"]),
            );
          }
        });
      }

      // Adapt the new members/{uid} shape (displayName, displayDob,
      // joinedAt, no dayStreak) back onto the field names
      // normalizeDashboardMember/buildDashboardMemberMetrics already expect
      // — those stay unchanged; only this trigger's input shape moved.
      const members = membersSnapshot.docs.map((doc) => {
        const data = doc.data();
        const linkedUid = readUnknownString(data["linkedUid"]);
        return {
          ...data,
          uid: doc.id,
          name: data["displayName"],
          dob: data["displayDob"],
          createdAt: data["joinedAt"],
          dayStreak: linkedUid ? streakByUid.get(linkedUid) ?? 0 : 0,
        };
      });

      const metrics = buildDashboardMemberMetrics(members);

      await firestore
        .collection("churches")
        .doc(churchId)
        .collection("dashboard_metrics")
        .doc("members")
        .set({
          ...metrics,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

      logger.info("Rebuilt church dashboard member metrics.", {
        churchId,
        memberCount: metrics.memberCount,
      });
    } catch (error) {
      logger.error("Failed to rebuild church dashboard member metrics.", {
        churchId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  },
);

/**
 * Notifies a person by push + email once their own request is approved —
 * only when they opted in via `notifyOnApproval` on `RequestPendingScreen`
 * (client). Fires once, on the false->true edge, so re-saving an already
 * approved membership (e.g. editing category) never re-sends it.
 */
export const notifyMemberOnApproval = onDocumentWritten(
  {
    document: "churches/{churchId}/members/{memberId}",
    database: firestoreDatabaseIdParam,
    region: "us-central1",
  },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!after?.exists) return;

    const wasApproved = before?.exists && before.data()?.approved === true;
    const isApproved = after.data()?.approved === true;
    if (wasApproved || !isApproved) return;
    if (after.data()?.notifyOnApproval !== true) return;

    const churchId = readUnknownString(event.params.churchId);
    const uid = readUnknownString(after.data()?.uid) ||
      readUnknownString(event.params.memberId);
    if (!churchId || !uid) return;

    try {
      const firestore = firestoreDb();
      const [churchDoc, identityDoc] = await Promise.all([
        firestore.collection("churches").doc(churchId).get(),
        firestore.collection("users").doc(uid).get(),
      ]);
      const churchName =
        readUnknownString(churchDoc.data()?.name) || "your church";
      const email = readUnknownString(identityDoc.data()?.email) ||
        readUnknownString(after.data()?.displayEmail);

      const tokensByUid = await resolveDeviceTokensByUid([uid]);
      const tokens = tokensByUid.get(uid) ?? [];
      const title = "You're in!";
      const body = `${churchName} approved your request. Welcome!`;

      if (tokens.length > 0) {
        const response = await admin.messaging().sendEach(
          tokens.map((token) => ({
            token,
            notification: {title, body},
            data: {kind: "membership_approved", churchId},
          })),
        );
        logger.info("Sent membership-approved push.", {
          churchId,
          uid,
          successCount: response.successCount,
        });
      }

      if (email) {
        const text = [
          "Hello,",
          "",
          `Your request to join "${churchName}" has been approved.`,
          "Open the app to get started.",
          "",
          "Warm regards,",
          "The Church App Team",
        ].join("\n");

        await firestore.collection("mail").add({
          kind: "membership_approved",
          template: "membership_approved",
          to: [email],
          subject: `You're approved to join ${churchName}`,
          text,
          html: textToHtml(text),
          data: {churchId, uid},
          status: "queued",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      logger.error("Failed to send membership-approved notification.", {
        churchId,
        uid,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  },
);

/**
 * Mirrors a deliberately reduced subset of an approved member's fields —
 * name, photo, dob, gender, marital status only — into
 * `churches/{churchId}/memberDirectory/{memberId}`, which any approved
 * member (not just staff) can read. Keeps phone/email/address/baptism/
 * financial/notes staff-only on the real `members/{memberId}` doc, since
 * Firestore has no field-level security and that doc's full read is
 * `isSelf || isChurchStaff` only. Removes the mirror when the member is
 * deleted or no longer approved, so the directory only ever shows current,
 * approved members.
 */
export const mirrorMemberDirectory = onDocumentWritten(
  {
    document: "churches/{churchId}/members/{memberId}",
    database: firestoreDatabaseIdParam,
    region: "us-central1",
  },
  async (event) => {
    const churchId = readUnknownString(event.params.churchId);
    const memberId = readUnknownString(event.params.memberId);
    if (!churchId || !memberId) return;

    const directoryRef = firestoreDb()
      .collection("churches").doc(churchId)
      .collection("memberDirectory").doc(memberId);

    const after = event.data?.after;
    const isApproved = after?.exists && after.data()?.approved === true;
    if (!isApproved) {
      await directoryRef.delete().catch(() => null);
      return;
    }

    const data = after.data() ?? {};
    try {
      await directoryRef.set({
        uid: memberId,
        displayName: readUnknownString(data.displayName),
        displayPhotoUrl: readUnknownString(data.displayPhotoUrl),
        displayDob: data.displayDob ?? null,
        displayGender: readUnknownString(data.displayGender),
        displayMaritalStatus: readUnknownString(data.displayMaritalStatus),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      logger.error("Failed to mirror member directory entry.", {
        churchId,
        memberId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  },
);

export const advanceRecurringEventOnWrite = onDocumentWritten(
  {
    document: "churches/{churchId}/events/{eventId}",
    region: "us-central1",
  },
  async (event) => {
    const data = event.data?.after.data() as RecurringEventData | undefined;
    if (!data || data.isRecurring !== true || data.active === false) return;

    await advanceRecurringEventIfNeeded(
      event.params.churchId,
      event.params.eventId,
      data,
    );
  },
);

export const advanceRecurringEventsHourly = onSchedule(
  {
    schedule: "every 1 hours",
    region: "us-central1",
    timeZone: recurringEventTimeZone,
  },
  async () => {
    const firestore = admin.firestore();
    const churchesSnapshot = await firestore.collection("churches").get();
    let advancedEventCount = 0;

    for (const churchDoc of churchesSnapshot.docs) {
      const eventsSnapshot = await churchDoc.ref
        .collection("events")
        .where("isRecurring", "==", true)
        .where("recurrenceFrequency", "==", "weekly")
        .get();

      for (const eventDoc of eventsSnapshot.docs) {
        const didAdvance = await advanceRecurringEventIfNeeded(
          churchDoc.id,
          eventDoc.id,
          eventDoc.data() as RecurringEventData,
        );
        if (didAdvance) advancedEventCount += 1;
      }
    }

    logger.info("Advanced recurring events.", {advancedEventCount});
  },
);

async function advanceRecurringEventIfNeeded(
  churchId: string,
  eventId: string,
  data: RecurringEventData,
): Promise<boolean> {
  if (data.isRecurring !== true) return false;
  if (data.recurrenceFrequency !== "weekly") return false;

  const startAt = readUnknownDate(data.startAt);
  if (startAt === null) {
    logger.warn("Recurring event missing startAt.", {churchId, eventId});
    return false;
  }

  const intervalWeeks = clampInteger(data.recurrenceIntervalWeeks, 1, 12, 1);
  const timeZone =
    readUnknownString(data.recurrenceTimeZone) || recurringEventTimeZone;
  const now = new Date();
  const nextStart = nextOccurrenceOnOrAfter(startAt, now, intervalWeeks);

  if (nextStart.getTime() === startAt.getTime()) return false;

  await admin.firestore()
    .collection("churches")
    .doc(churchId)
    .collection("events")
    .doc(eventId)
    .set(
      {
        timing: formatEventTiming(nextStart, timeZone),
        startAt: admin.firestore.Timestamp.fromDate(nextStart),
        expiryAt: admin.firestore.Timestamp.fromDate(endOfDay(nextStart)),
        recurrenceLastAdvancedAt:
          admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

  return true;
}

function nextOccurrenceOnOrAfter(
  startAt: Date,
  target: Date,
  intervalWeeks: number,
): Date {
  const intervalMs = intervalWeeks * 7 * 24 * 60 * 60 * 1000;
  if (startAt.getTime() >= target.getTime()) return new Date(startAt);

  const elapsed = target.getTime() - startAt.getTime();
  const steps = Math.ceil(elapsed / intervalMs);
  return new Date(startAt.getTime() + steps * intervalMs);
}

function endOfDay(value: Date): Date {
  const date = new Date(value);
  date.setHours(23, 59, 59, 999);
  return date;
}

function formatEventTiming(value: Date, timeZone: string): string {
  return new Intl.DateTimeFormat("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
    timeZone,
  }).format(value);
}

function clampInteger(
  value: unknown,
  minimum: number,
  maximum: number,
  fallback: number,
): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.min(maximum, Math.max(minimum, Math.trunc(value)));
}

/**
 * Normalizes the queued recipients into a unique lowercase email list.
 * @param value Mail recipient payload from the queue document.
 * @return Normalized recipient emails.
 */
function normalizeRecipients(value: MailJobData["to"]): string[] {
  if (Array.isArray(value)) {
    return [...new Set(value.map(normalizeEmail).filter(Boolean))];
  }

  if (typeof value === "string") {
    const email = normalizeEmail(value);
    return email ? [email] : [];
  }

  return [];
}

/**
 * Normalizes a single email address for delivery.
 * @param value Email address to normalize.
 * @return Lowercased trimmed email.
 */
function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

/**
 * Resolves the email subject, preferring explicit queue content.
 * @param job Mail job payload.
 * @return Subject line for the email.
 */
function resolveSubject(job: MailJobData): string {
  const explicitSubject = (job.subject ?? "").trim();
  if (explicitSubject.length > 0) return explicitSubject;

  const churchName = readString(job.data, "churchName") || "Church";
  switch (job.template) {
    case "church_created":
      return `Church created: ${churchName}`;
    case "church_enabled":
      return `Church enabled: ${churchName}`;
    case "church_disabled":
      return `Church disabled: ${churchName}`;
    default:
      return "Super admin church update";
  }
}

/**
 * Resolves the email body, preferring explicit queue content.
 * @param job Mail job payload.
 * @return Plain text body for the email.
 */
function resolveText(job: MailJobData): string {
  const explicitText = (job.text ?? "").trim();
  if (explicitText.length > 0) return explicitText;

  const churchName = readString(job.data, "churchName") || "your church";
  const churchId = readString(job.data, "churchId") || "-";

  switch (job.template) {
    case "church_created":
      return [
        "Hello Admin,",
        "",
        `Your church "${churchName}" has been created ` +
            "from the super admin dashboard. Now can you see your church " +
            "listed in our app",
        `Church ID: ${churchId}`,
      ].join("\n");
    case "church_enabled":
      return [
        "Hello Admin,",
        "",
        `Your church "${churchName}" has been enabled ` +
            "from the super admin dashboard.",
        `Church ID: ${churchId}`,
      ].join("\n");
    case "church_disabled":
      return [
        "Hello Admin,",
        "",
        `Your church "${churchName}" has been disabled ` +
            "from the super admin dashboard.",
        `Church ID: ${churchId}`,
      ].join("\n");
    default:
      return "";
  }
}

/**
 * Reads a trimmed string field from a generic payload object.
 * @param data Source payload map.
 * @param key Field name to read.
 * @return Trimmed string value or an empty string.
 */
function readString(
  data: Record<string, unknown> | undefined,
  key: string,
): string {
  const value = data?.[key];
  return typeof value === "string" ? value.trim() : "";
}

/**
 * Converts plain text into minimal safe HTML.
 * @param value Plain text content.
 * @return HTML-safe content with line breaks preserved.
 */
function textToHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\n/g, "<br>");
}

function createTransporter() {
  return nodemailer.createTransport({
    host: smtpHost.value(),
    port: Number.parseInt(smtpPort.value() || "587", 10),
    secure: (smtpSecure.value() || "false").toLowerCase() == "true",
    auth: {
      user: smtpUser.value(),
      pass: smtpPass.value(),
    },
  });
}

function passwordResetChallengeId(email: string): string {
  return createHmac("sha256", smtpPass.value())
    .update(normalizeEmail(email))
    .digest("hex");
}

function passwordResetCodeHash(challengeId: string, code: string): string {
  return createHmac("sha256", smtpPass.value())
    .update(`${challengeId}:${code}`)
    .digest("hex");
}

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function secureStringEqual(left: string, right: string): boolean {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  return leftBuffer.length === rightBuffer.length &&
    timingSafeEqual(leftBuffer, rightBuffer);
}

function timestampMillis(value: unknown): number {
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  return 0;
}

function buildAppPasswordResetLink({
  firebaseResetLink,
  email,
  churchName,
}: {
  firebaseResetLink: string;
  email: string;
  churchName: string;
}): string {
  const firebaseUrl = new URL(firebaseResetLink);
  const oobCode = firebaseUrl.searchParams.get("oobCode");
  if (oobCode === null || oobCode.trim().length === 0) {
    return firebaseResetLink;
  }

  const appUrl = new URL(passwordResetAppUrl);
  appUrl.searchParams.set("mode", "resetPassword");
  appUrl.searchParams.set("oobCode", oobCode);
  appUrl.searchParams.set("email", email);
  if (churchName.trim().length > 0) {
    appUrl.searchParams.set("churchName", churchName.trim());
  }
  return appUrl.toString();
}

function readUnknownString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function buildDashboardMemberMetrics(
  rawMembers: Array<Record<string, unknown>>,
) {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const members = rawMembers.map(normalizeDashboardMember);
  const datedMembers = members
    .filter((member) => member.createdAt !== null)
    .sort((a, b) => {
      if (a.createdAt === null || b.createdAt === null) return 0;
      return b.createdAt.getTime() - a.createdAt.getTime();
    });

  const approvedMembers = members.filter((member) => member.approved).length;
  const pendingApprovals = members.length - approvedMembers;
  const familyCount = members
    .filter((member) => member.category === "family")
    .length;
  const individualCount = members
    .filter((member) => member.category === "individual")
    .length;
  const membersWithGroups = members
    .filter((member) => member.churchGroupIds.length > 0)
    .length;
  const groupParticipationRate = members.length === 0 ? 0 :
    Math.round((membersWithGroups / members.length) * 100);
  const recentJoinCount7d = datedMembers
    .filter((member) => member.createdAt !== null &&
      differenceInDays(today, member.createdAt) <= 7)
    .length;
  const recentJoinCount30d = datedMembers
    .filter((member) => member.createdAt !== null &&
      differenceInDays(today, member.createdAt) <= 30)
    .length;
  const recentJoinCount90d = datedMembers
    .filter((member) => member.createdAt !== null &&
      differenceInDays(today, member.createdAt) <= 90)
    .length;
  const joinedThisYear = datedMembers
    .filter((member) => member.createdAt !== null &&
      member.createdAt.getFullYear() === now.getFullYear())
    .length;

  const streakMembers = [...members]
    .filter((member) => member.dayStreak > 0)
    .sort(
      (a, b) => b.dayStreak - a.dayStreak || a.name.localeCompare(b.name),
    );
  const activeStreakMembersCount = streakMembers.length;
  const membersWith7PlusCount = streakMembers
    .filter((member) => member.dayStreak >= 7)
    .length;
  const activeStreakRate = members.length === 0 ? 0 :
    Math.round((activeStreakMembersCount / members.length) * 100);
  const topStreakMember = streakMembers.length > 0 ?
    buildPreviewMember(streakMembers[0], "Streak leader") :
    null;

  return {
    memberCount: members.length,
    approvedMembers,
    pendingApprovals,
    familyCount,
    individualCount,
    membersWithGroups,
    groupParticipationRate,
    recentJoinCount7d,
    recentJoinCount30d,
    recentJoinCount90d,
    joinedThisYear,
    firstRecordedAt:
      datedMembers.length > 0 &&
        datedMembers[datedMembers.length - 1].createdAt ?
        admin.firestore.Timestamp.fromDate(
          datedMembers[datedMembers.length - 1].createdAt as Date,
        ) :
        null,
    recentMembers: datedMembers.slice(0, 3).map((member) => ({
      uid: member.uid,
      name: member.name,
      secondary: member.approved ? "Approved" : "Pending",
      approved: member.approved,
    })),
    activeStreakMembersCount,
    membersWith7PlusCount,
    activeStreakRate,
    topStreakValue: topStreakMember ? streakMembers[0].dayStreak : 0,
    topStreakMember,
    genderBuckets: buildDashboardBuckets(
      members,
      [
        {
          id: "male",
          label: "Male",
          match: (member) => member.gender === "male",
        },
        {
          id: "female",
          label: "Female",
          match: (member) => member.gender === "female",
        },
        {
          id: "unknown",
          label: "Unknown",
          match: (member) =>
            member.gender !== "male" && member.gender !== "female",
        },
      ],
      (member) => buildPreviewMember(member, member.genderLabel),
    ),
    ageBuckets: buildDashboardBuckets(
      members,
      [
        {
          id: "children",
          label: "Children",
          match: (member) => member.age !== null && member.age <= 12,
        },
        {
          id: "youth",
          label: "Youth",
          match: (member) =>
            member.age !== null &&
            member.age >= 13 &&
            member.age <= 24,
        },
        {
          id: "adults",
          label: "Adults",
          match: (member) =>
            member.age !== null &&
            member.age >= 25 &&
            member.age <= 59,
        },
        {
          id: "seniors",
          label: "Seniors",
          match: (member) => member.age !== null && member.age >= 60,
        },
        {
          id: "unknown",
          label: "Unknown",
          match: (member) => member.age === null,
        },
      ],
      (member) => buildPreviewMember(
        member,
        member.age === null ? "DOB missing" : `${member.age} years`,
      ),
    ),
    familyModeBuckets: buildDashboardBuckets(
      members,
      [
        {
          id: "family",
          label: "Family",
          match: (member) => member.category === "family",
        },
        {
          id: "individual",
          label: "Individual",
          match: (member) => member.category === "individual",
        },
        {
          id: "other",
          label: "Other",
          match: (member) =>
            member.category.length > 0 &&
            member.category !== "family" &&
            member.category !== "individual",
        },
        {
          id: "unspecified",
          label: "Unspecified",
          match: (member) => member.category.length === 0,
        },
      ],
      (member) => buildPreviewMember(member, member.categoryLabel),
    ),
    solemnizedBuckets: buildDashboardBuckets(
      members,
      [
        {
          id: "solemnized",
          label: "Solemnized",
          match: (member) => member.solemnizedBaptism,
        },
        {
          id: "not_solemnized",
          label: "Not solemnized",
          match: (member) => !member.solemnizedBaptism,
        },
      ],
      (member) => buildPreviewMember(member, member.solemnizedLabel),
    ),
    familyBuckets: buildFamilyBuckets(members),
  };
}

function normalizeDashboardMember(raw: Record<string, unknown>) {
  const dob = readUnknownDate(raw["dob"]);
  const createdAt = readUnknownDate(raw["createdAt"]);
  const dayStreak = readUnknownInteger(raw["dayStreak"]);
  const gender = readUnknownString(raw["gender"]).toLowerCase();
  const category = readUnknownString(raw["category"]).toLowerCase();
  const familyId = readUnknownString(raw["familyId"]);
  const solemnizedBaptism = raw["solemnizedBaptism"] === true;
  const baptismChurchName = readUnknownString(raw["baptismChurchName"]);
  const churchGroupIds = Array.isArray(raw["churchGroupIds"]) ?
    raw["churchGroupIds"]
      .map((item) => readUnknownString(item))
      .filter((item) => item.length > 0) :
    [];
  const age = dob ? ageOf(dob) : null;

  return {
    uid: readUnknownString(raw["uid"]) || readUnknownString(raw["id"]),
    name: readUnknownString(raw["name"]) || "Member",
    approved: raw["approved"] === true,
    gender,
    genderLabel: gender.length === 0 ?
      "Unspecified gender" :
      titleCase(gender),
    category,
    categoryLabel: category.length === 0 ?
      "Unspecified category" :
      titleCase(category),
    familyId,
    solemnizedBaptism,
    baptismChurchName,
    churchGroupIds,
    createdAt,
    dayStreak,
    age,
    solemnizedLabel: !solemnizedBaptism ?
      "No baptism record yet" :
      baptismChurchName.length > 0 ?
        baptismChurchName :
        "Baptism recorded",
  };
}

function buildPreviewMember(
  member: ReturnType<typeof normalizeDashboardMember>,
  secondary: string,
): DashboardPreviewMemberPayload {
  return {
    uid: member.uid,
    name: member.name,
    secondary,
    approved: member.approved,
  };
}

function buildDashboardBuckets(
  members: Array<ReturnType<typeof normalizeDashboardMember>>,
  config: Array<{
    id: string;
    label: string;
    match: (member: ReturnType<typeof normalizeDashboardMember>) => boolean;
  }>,
  previewBuilder: (
    member: ReturnType<typeof normalizeDashboardMember>,
  ) => DashboardPreviewMemberPayload,
): DashboardMetricBucketPayload[] {
  return config.map((bucket) => {
    const bucketMembers = members
      .filter((member) => bucket.match(member))
      .sort((a, b) => a.name.localeCompare(b.name));

    return {
      id: bucket.id,
      label: bucket.label,
      count: bucketMembers.length,
      previewMembers: bucketMembers.slice(0, 5).map(previewBuilder),
    };
  }).filter((bucket) => bucket.count > 0);
}

function buildFamilyBuckets(
  members: Array<ReturnType<typeof normalizeDashboardMember>>,
): DashboardFamilyBucketPayload[] {
  const grouped = new Map<string, DashboardFamilyBucketPayload>();

  for (const member of members.filter((item) => {
    const familyId = item.familyId.trim().toLowerCase();
    return item.category === "family" || familyId.startsWith("family_");
  })) {
    const familyId = member.familyId.length > 0 ?
      member.familyId :
      "unknown_family";
    const label = formatFamilyLabel(familyId);
    const existing = grouped.get(label);
    if (existing) {
      existing.count += 1;
      if (!existing.familyIds.includes(familyId)) {
        existing.familyIds.push(familyId);
      }
      continue;
    }

    grouped.set(label, {
      id: label
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "_")
        .replace(/^_+|_+$/g, ""),
      label,
      count: 1,
      familyIds: [familyId],
    });
  }

  return [...grouped.values()]
    .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label));
}

function readUnknownDate(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function readUnknownInteger(value: unknown): number {
  if (typeof value === "number") return Math.round(value);
  if (typeof value === "string") {
    return Number.parseInt(value.trim() || "0", 10) || 0;
  }
  return 0;
}

function ageOf(dob: Date): number {
  const now = new Date();
  let age = now.getFullYear() - dob.getFullYear();
  const hadBirthday = now.getMonth() > dob.getMonth() ||
    (now.getMonth() === dob.getMonth() && now.getDate() >= dob.getDate());
  if (!hadBirthday) age -= 1;
  return age;
}

function differenceInDays(a: Date, b: Date): number {
  return Math.floor((a.getTime() - b.getTime()) / (1000 * 60 * 60 * 24));
}

function titleCase(value: string): string {
  if (value.length === 0) return "";
  return value[0].toUpperCase() + value.slice(1);
}

function formatFamilyLabel(familyId: string): string {
  const normalized = familyId.trim().toLowerCase();
  if (normalized.length === 0 || normalized === "unknown_family") {
    return "Unknown family";
  }

  let cleaned = normalized
    .replace(/^family_/, "")
    .replace(/^individual_/, "");

  const parts = cleaned.split("_").filter(Boolean);
  if (parts.length > 1) {
    parts.pop();
  }

  cleaned = parts
    .map((part) => titleCase(part))
    .join(" ")
    .trim();

  if (cleaned.length === 0) {
    return "Unknown family";
  }

  return cleaned.endsWith("s") ? `${cleaned}' family` : `${cleaned}'s family`;
}
