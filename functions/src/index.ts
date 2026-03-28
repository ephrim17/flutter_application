/* eslint-disable indent, require-jsdoc, valid-jsdoc */
import * as admin from "firebase-admin";
import {logger} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {defineSecret, defineString} from "firebase-functions/params";
import nodemailer from "nodemailer";

admin.initializeApp();

const smtpHost = defineString("SMTP_HOST");
const smtpPort = defineString("SMTP_PORT");
const smtpSecure = defineString("SMTP_SECURE");
const emailFrom = defineString("EMAIL_FROM");
const smtpUser = defineSecret("SMTP_USER");
const smtpPass = defineSecret("SMTP_PASS");

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
};

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
      const subject = mode == "setup" ?
        `Set up your ${churchName} password` :
        `Reset your ${churchName} password`;
      const text = mode == "setup" ?
        [
          "Hello,",
          "",
          `Your account for ${churchName} is ready.`,
          "Use the link below to set your password and complete setup:",
          resetLink,
          "",
          "If you were not expecting this email, you can ignore it.",
        ].join("\n") :
        [
          "Hello,",
          "",
          `We received a request to reset your password for ${churchName}.`,
          "Use the link below to choose a new password:",
          resetLink,
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
    topic: payload.topic,
  });
}

export const processQueuedChurchNotification = onDocumentCreated(
  {
    document: "churches/{churchId}/notification_requests/{notificationId}",
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

    if (!title || !body || !topic) {
      await snapshot.ref.update({
        status: "failed",
        error: "Missing required notification fields",
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    try {
      await sendTopicNotification({title, body, topic});

      await snapshot.ref.update({
        status: "sent",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
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

export const notifyOnFeedPostCreated = onDocumentCreated(
  {
    document: "churches/{churchId}/feeds/{feedId}",
    region: "us-central1",
  },
  async (event) => {
    const snapshot = event.data;
    const data = snapshot?.data();
    const churchId = readUnknownString(event.params.churchId);

    if (!data || !churchId) {
      logger.warn("Feed notification trigger missing data.", {
        params: event.params,
      });
      return;
    }

    const userName = readUnknownString(data.userName) || "Someone";

    try {
      await sendTopicNotification({
        title: `${userName} has posted a new feed`,
        body: "Tap to see more",
        topic: `church_${churchId}`,
      });

      logger.info("Feed post notification sent.", {
        feedId: snapshot?.id ?? null,
        churchId,
      });
    } catch (error) {
      logger.error("Failed to send feed post notification.", {
        churchId,
        feedId: snapshot?.id ?? null,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  },
);

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
            "from the super admin dashboard.",
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

function readUnknownString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}
