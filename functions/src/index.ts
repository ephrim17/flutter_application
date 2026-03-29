/* eslint-disable indent, require-jsdoc, valid-jsdoc */
import * as admin from "firebase-admin";
import {logger} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
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

export const rebuildChurchDashboardMemberMetrics = onDocumentWritten(
  {
    document: "churches/{churchId}/users/{uid}",
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
      const usersSnapshot = await admin.firestore()
        .collection("churches")
        .doc(churchId)
        .collection("users")
        .get();

      const members = usersSnapshot.docs.map((doc) => ({
        uid: doc.id,
        ...doc.data(),
      }));

      const metrics = buildDashboardMemberMetrics(members);

      await admin.firestore()
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
