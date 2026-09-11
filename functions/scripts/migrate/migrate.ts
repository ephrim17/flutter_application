import * as admin from "firebase-admin";
import {
  ChurchReport,
  CliOptions,
  ConflictRow,
  RunReport,
  emptyChurchReport,
} from "./types";
import {MergedIdentity, OldMemberRow, mergeIdentity} from "./identity";
import {migrateAvatarBlob} from "./avatarBlob";
import {
  loadChurchModuleIndex,
  resolveModuleSource,
  resolveSectionOwner,
} from "./moduleSource";

type Firestore = FirebaseFirestore.Firestore;
type DocData = FirebaseFirestore.DocumentData;

interface ResolvedRow extends OldMemberRow {
  linkedUid: string | null;
}

interface AttemptRecord {
  moduleId?: string;
  answers?: unknown;
  score?: number;
  total?: number;
  passed?: boolean;
  attemptNumber?: number;
  completedAt?: FirebaseFirestore.Timestamp;
}

interface OldProgressDoc {
  completedSectionIds?: unknown[];
  completedModuleIds?: unknown[];
  attempts?: Record<string, AttemptRecord>;
  attemptCounts?: Record<string, number>;
  moduleAttemptCounts?: Record<string, number>;
}

interface ProgressAccumulator {
  completedSectionIds: Set<string>;
  completedModuleIds: Set<string>;
  attempts: Record<string, AttemptRecord>;
  attemptCounts: Record<string, number>;
  moduleAttemptCounts: Record<string, number>;
}

/**
 * Builds an empty learning-progress accumulator.
 * @return {ProgressAccumulator} A zeroed accumulator.
 */
function newAccumulator(): ProgressAccumulator {
  return {
    completedSectionIds: new Set(),
    completedModuleIds: new Set(),
    attempts: {},
    attemptCounts: {},
    moduleAttemptCounts: {},
  };
}

/**
 * Picks the better of two colliding attempts at the same global section
 * (the person did the same Church Tree module in two churches): passed
 * beats failed, then higher score, then more recent.
 * @param {AttemptRecord} a One candidate attempt.
 * @param {AttemptRecord} b The other candidate attempt.
 * @return {AttemptRecord} The winning attempt.
 */
function betterAttempt(a: AttemptRecord, b: AttemptRecord): AttemptRecord {
  if ((a.passed === true) !== (b.passed === true)) {
    return a.passed ? a : b;
  }
  const scoreA = typeof a.score === "number" ? a.score : -1;
  const scoreB = typeof b.score === "number" ? b.score : -1;
  if (scoreA !== scoreB) return scoreA > scoreB ? a : b;
  const timeA = a.completedAt?.toMillis() ?? 0;
  const timeB = b.completedAt?.toMillis() ?? 0;
  return timeA >= timeB ? a : b;
}

/**
 * Merges one attempt-count entry into an accumulator, keeping the max
 * across colliding churches.
 * @param {Record<string, number>} target Accumulator map, mutated in
 * place.
 * @param {string} key Section or module id.
 * @param {number} value Count to merge in.
 * @return {void}
 */
function mergeAttemptCount(
  target: Record<string, number>,
  key: string,
  value: number,
): void {
  target[key] = Math.max(target[key] ?? 0, value);
}

const authExistsCache = new Map<string, boolean>();

/**
 * Checks (and caches) whether an id is a real Firebase Auth uid — the
 * linked/unlinked test from §9.3/§9.4.
 * @param {admin.auth.Auth} auth Admin Auth instance.
 * @param {string} uid Candidate uid (an old row's doc id).
 * @return {Promise<boolean>} True if a real auth user exists with this id.
 */
async function isRealAuthUid(
  auth: admin.auth.Auth,
  uid: string,
): Promise<boolean> {
  const cached = authExistsCache.get(uid);
  if (cached !== undefined) return cached;
  try {
    await auth.getUser(uid);
    authExistsCache.set(uid, true);
    return true;
  } catch {
    authExistsCache.set(uid, false);
    return false;
  }
}

/**
 * Resolves an email to an existing Firebase Auth uid, for legacy
 * email-keyed group-member rows (§9.4).
 * @param {admin.auth.Auth} auth Admin Auth instance.
 * @param {string} email Email to resolve.
 * @return {Promise<string | null>} The matching uid, or null if none.
 */
async function resolveUidByEmail(
  auth: admin.auth.Auth,
  email: string,
): Promise<string | null> {
  if (!email) return null;
  try {
    const user = await auth.getUserByEmail(email);
    return user.uid;
  } catch {
    return null;
  }
}

/**
 * Reads a Firestore Timestamp field as a Date, or the epoch if absent —
 * used only as a recency signal (§9.5-adjacent gap, see identity.ts).
 * @param {unknown} value Raw Firestore field value.
 * @return {Date} The timestamp's Date, or the epoch.
 */
function timestampToDate(value: unknown): Date {
  if (value && typeof (value as {toDate?: unknown}).toDate === "function") {
    return (value as FirebaseFirestore.Timestamp).toDate();
  }
  return new Date(0);
}

/**
 * Runs the Phase 2 backfill: reads every church's pre-migration
 * `users` rows, resolves person identities across churches, and (unless
 * `options.dryRun`) writes the new `users/{uid}` + `churches/{cid}/members`
 * shape, splits learning progress by module source (§5.6), tags existing
 * `learning_results` rows, moves `readingPlans`, and re-keys
 * `groups/{gid}/users` -> `groupMembers`.
 *
 * Non-destructive by design: this only ever writes new paths. It never
 * deletes the old `churches/{cid}/users` rows or the old
 * `groups/{gid}/users` rows — Phase 8's production cutover, run manually,
 * is the point at which the app stops reading the old paths at all.
 * @param {Firestore} firestore Target Firestore instance (already bound to
 * the right database — see cli.ts's refusal to --write against
 * "(default)").
 * @param {admin.auth.Auth} auth Admin Auth instance, used only to resolve
 * which old row ids are real signed-in people (§9.3/§9.4).
 * @param {admin.storage.Storage} storage Admin Storage instance — Storage
 * is project-wide, not per-database, so the same bucket holds both old and
 * new avatar paths regardless of which Firestore database this run
 * targets.
 * @param {CliOptions} options Parsed CLI options.
 * @return {Promise<{report: RunReport, conflicts: ConflictRow[]}>} The run
 * report and the full conflicts list.
 */
export async function runMigration(
  firestore: Firestore,
  auth: admin.auth.Auth,
  storage: admin.storage.Storage,
  options: CliOptions,
): Promise<{report: RunReport; conflicts: ConflictRow[]}> {
  const startedAt = new Date().toISOString();
  const conflicts: ConflictRow[] = [];
  const churchReports: ChurchReport[] = [];

  const churchesSnapshot = await firestore.collection("churches").get();
  let churchDocs = churchesSnapshot.docs;
  if (options.churchIds) {
    const wanted = new Set(options.churchIds);
    churchDocs = churchDocs.filter((doc) => wanted.has(doc.id));
  }

  // ---- Pass 1: read every old row, per church, and classify linked vs
  // unlinked (§9.3/§9.4) up front, since identity merging needs the full
  // cross-church picture before anything is written.
  const rowsByChurch = new Map<string, ResolvedRow[]>();
  for (const churchDoc of churchDocs) {
    const churchId = churchDoc.id;
    const oldUsersSnapshot = await firestore
      .collection("churches").doc(churchId).collection("users").get();

    const rows: ResolvedRow[] = [];
    for (const doc of oldUsersSnapshot.docs) {
      const linked = await isRealAuthUid(auth, doc.id);
      rows.push({
        churchId,
        oldDocId: doc.id,
        data: doc.data(),
        recency: timestampToDate(doc.data()["createdAt"]),
        linkedUid: linked ? doc.id : null,
      });
    }
    rowsByChurch.set(churchId, rows);
  }

  // ---- Cross-church identity merge (linked rows only).
  const rowsByUid = new Map<string, ResolvedRow[]>();
  for (const rows of rowsByChurch.values()) {
    for (const row of rows) {
      if (!row.linkedUid) continue;
      const bucket = rowsByUid.get(row.linkedUid) ?? [];
      bucket.push(row);
      rowsByUid.set(row.linkedUid, bucket);
    }
  }
  const identitiesByUid = new Map<string, MergedIdentity>();
  for (const [uid, rows] of rowsByUid) {
    identitiesByUid.set(uid, mergeIdentity(uid, rows, conflicts));
  }

  // ---- Reading plans: merge across churches per uid, union completedDays
  // per month, keep the latest updatedAt (linked members only — an
  // unlinked row has no `users/{uid}` to own a cross-church reading plan).
  const readingPlansByUid = new Map<
    string, Map<string, {completedDays: Set<number>;
      updatedAt: FirebaseFirestore.Timestamp | null}>
  >();
  for (const [churchId, rows] of rowsByChurch) {
    for (const row of rows) {
      if (!row.linkedUid) continue;
      const plansSnapshot = await firestore
        .collection("churches").doc(churchId)
        .collection("users").doc(row.oldDocId)
        .collection("readingPlans").get();
      if (plansSnapshot.empty) continue;

      const perUid = readingPlansByUid.get(row.linkedUid) ?? new Map();
      for (const planDoc of plansSnapshot.docs) {
        const month = planDoc.id;
        const days = Array.isArray(planDoc.data()["completedDays"]) ?
          planDoc.data()["completedDays"] as number[] :
          [];
        const updatedAt = planDoc.data()["updatedAt"] as
          FirebaseFirestore.Timestamp | undefined;
        const existing = perUid.get(month) ?? {
          completedDays: new Set<number>(),
          updatedAt: null,
        };
        days.forEach((day) => existing.completedDays.add(day));
        if (updatedAt && (!existing.updatedAt ||
            updatedAt.toMillis() > existing.updatedAt.toMillis())) {
          existing.updatedAt = updatedAt;
        }
        perUid.set(month, existing);
      }
      readingPlansByUid.set(row.linkedUid, perUid);
    }
  }

  // ---- Learning progress: split by module source (§5.6), merging the
  // global track across churches per uid; the church track stays
  // per-membership, no merge needed.
  const globalProgressByUid = new Map<string, ProgressAccumulator>();
  const churchProgressByRow = new Map<string, ProgressAccumulator>();
  const droppedIdsByChurch = new Map<string, number>();

  for (const [churchId, rows] of rowsByChurch) {
    const moduleIndex = await loadChurchModuleIndex(firestore, churchId);
    for (const row of rows) {
      const progressDoc = await firestore
        .collection("churches").doc(churchId)
        .collection("users").doc(row.oldDocId)
        .collection("learning_progress").doc("progress").get();
      if (!progressDoc.exists) continue;
      const data = progressDoc.data() as OldProgressDoc;

      const churchAcc = newAccumulator();
      const globalAcc = row.linkedUid ?
        (globalProgressByUid.get(row.linkedUid) ?? newAccumulator()) :
        null;
      let dropped = 0;

      for (const rawId of data.completedModuleIds ?? []) {
        const moduleId = String(rawId);
        const source = resolveModuleSource(moduleIndex, moduleId);
        if (source === "global" && globalAcc) {
          globalAcc.completedModuleIds.add(moduleId);
        } else if (source === "church") {
          churchAcc.completedModuleIds.add(moduleId);
        } else {
          dropped += 1;
        }
      }

      for (const rawId of data.completedSectionIds ?? []) {
        const sectionId = String(rawId);
        const owner = resolveSectionOwner(moduleIndex, sectionId);
        if (owner?.source === "global" && globalAcc) {
          globalAcc.completedSectionIds.add(sectionId);
        } else if (owner?.source === "church") {
          churchAcc.completedSectionIds.add(sectionId);
        } else {
          dropped += 1;
        }
      }

      for (const [sectionId, attempt] of
        Object.entries(data.attempts ?? {})) {
        const moduleId = attempt.moduleId ?
          String(attempt.moduleId) :
          resolveSectionOwner(moduleIndex, sectionId)?.moduleId ?? null;
        const source = moduleId ?
          resolveModuleSource(moduleIndex, moduleId) :
          null;
        if (source === "global" && globalAcc) {
          const existing = globalAcc.attempts[sectionId];
          globalAcc.attempts[sectionId] =
            existing ? betterAttempt(existing, attempt) : attempt;
        } else if (source === "church") {
          churchAcc.attempts[sectionId] = attempt;
        } else {
          dropped += 1;
        }
      }

      for (const [sectionId, count] of
        Object.entries(data.attemptCounts ?? {})) {
        const owner = resolveSectionOwner(moduleIndex, sectionId);
        if (owner?.source === "global" && globalAcc) {
          mergeAttemptCount(globalAcc.attemptCounts, sectionId, count);
        } else if (owner?.source === "church") {
          churchAcc.attemptCounts[sectionId] = count;
        }
      }

      for (const [moduleId, count] of
        Object.entries(data.moduleAttemptCounts ?? {})) {
        const source = resolveModuleSource(moduleIndex, moduleId);
        if (source === "global" && globalAcc) {
          mergeAttemptCount(globalAcc.moduleAttemptCounts, moduleId, count);
        } else if (source === "church") {
          churchAcc.moduleAttemptCounts[moduleId] = count;
        }
      }

      if (row.linkedUid && globalAcc) {
        globalProgressByUid.set(row.linkedUid, globalAcc);
      }
      churchProgressByRow.set(`${churchId}/${row.oldDocId}`, churchAcc);
      droppedIdsByChurch.set(
        churchId, (droppedIdsByChurch.get(churchId) ?? 0) + dropped,
      );
    }
  }

  // ---- Write phase. Every count below reflects what WOULD happen whether
  // or not options.dryRun is set — only the actual Firestore mutations are
  // gated on it, so a dry run's report is a true preview, not a blank one.
  let identitiesWritten = 0;
  let avatarBlobsMigrated = 0;
  for (const [uid, identity] of identitiesByUid) {
    const avatarResult = await migrateAvatarBlob(
      storage, uid, identity.profilePhotoUrl, options.dryRun,
    );
    if (avatarResult.copied) avatarBlobsMigrated += 1;

    if (!options.dryRun) {
      await firestore.collection("users").doc(uid).set({
        name: identity.name,
        email: identity.email,
        phone: identity.phone,
        profilePhotoUrl: avatarResult.url,
        dob: identity.dob,
        gender: identity.gender,
        location: identity.location,
        address: identity.address,
        maritalStatus: identity.maritalStatus,
        weddingDay: identity.weddingDay,
        educationalQualification: identity.educationalQualification,
        talentsAndGifts: identity.talentsAndGifts,
        dayStreak: identity.dayStreak,
        lastStreakRecordedAt: identity.lastStreakRecordedAt,
        lastActiveChurchId: null,
        profileComplete: identity.profileComplete,
        schemaVersion: 1,
        createdAt: identity.createdAt,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const plans = readingPlansByUid.get(uid);
      if (plans) {
        for (const [month, plan] of plans) {
          await firestore.collection("users").doc(uid)
            .collection("readingPlans").doc(month).set({
              completedDays: Array.from(plan.completedDays).sort(
                (a, b) => a - b,
              ),
              updatedAt: plan.updatedAt ??
                admin.firestore.FieldValue.serverTimestamp(),
            });
        }
      }

      const globalProgress = globalProgressByUid.get(uid);
      if (globalProgress) {
        await firestore.collection("users").doc(uid)
          .collection("learning_progress").doc("progress").set({
            completedSectionIds: Array.from(globalProgress.completedSectionIds),
            completedModuleIds: Array.from(globalProgress.completedModuleIds),
            attempts: globalProgress.attempts,
            attemptCounts: globalProgress.attemptCounts,
            moduleAttemptCounts: globalProgress.moduleAttemptCounts,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      }
    }
    identitiesWritten += 1;
  }

  for (const churchDoc of churchDocs) {
    const churchId = churchDoc.id;
    const rows = rowsByChurch.get(churchId) ?? [];
    const report = emptyChurchReport(
      churchId, String(churchDoc.data()["name"] ?? churchId),
    );
    report.oldMemberDocCount = rows.length;
    report.linkedMemberCount = rows.filter((r) => r.linkedUid).length;
    report.unlinkedMemberCount = rows.filter((r) => !r.linkedUid).length;
    report.learningProgressDroppedIds = droppedIdsByChurch.get(churchId) ?? 0;

    try {
      for (const row of rows) {
        const identity = row.linkedUid ?
          identitiesByUid.get(row.linkedUid) :
          null;
        if (!options.dryRun) {
          await firestore.collection("churches").doc(churchId)
            .collection("members").doc(row.oldDocId).set(
              buildMembershipDoc(row, identity),
            );
        }
        report.membershipsWritten += 1;

        const churchAcc = churchProgressByRow.get(
          `${churchId}/${row.oldDocId}`,
        );
        const hasChurchProgress = churchAcc && (
          churchAcc.completedModuleIds.size > 0 ||
          churchAcc.completedSectionIds.size > 0 ||
          Object.keys(churchAcc.attempts).length > 0
        );
        if (hasChurchProgress && churchAcc) {
          if (!options.dryRun) {
            await firestore.collection("churches").doc(churchId)
              .collection("members").doc(row.oldDocId)
              .collection("learning_progress").doc("progress").set({
                completedSectionIds:
                  Array.from(churchAcc.completedSectionIds),
                completedModuleIds: Array.from(churchAcc.completedModuleIds),
                attempts: churchAcc.attempts,
                attemptCounts: churchAcc.attemptCounts,
                moduleAttemptCounts: churchAcc.moduleAttemptCounts,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
          }
          report.learningProgressChurchIdsKept +=
            churchAcc.completedModuleIds.size +
            churchAcc.completedSectionIds.size;
        }
      }

      const {tagged, unresolved} =
        await tagLearningResults(firestore, churchId, options.dryRun);
      report.learningResultsTagged = tagged;
      report.learningResultsUnresolved = unresolved;

      const {rekeyed, unresolved: groupsUnresolved} =
        await rekeyGroupMembers(firestore, auth, churchId, options.dryRun);
      report.groupMembersRekeyed = rekeyed;
      report.groupMembersUnresolved = groupsUnresolved;

      const linkedUidsInChurch = Array.from(new Set(
        rows.map((r) => r.linkedUid).filter(
          (uid): uid is string => uid !== null,
        ),
      ));
      report.readingPlanDocsMoved = linkedUidsInChurch.reduce(
        (sum, uid) => sum + (readingPlansByUid.get(uid)?.size ?? 0),
        0,
      );
      report.learningProgressGlobalIdsMerged = linkedUidsInChurch
        .reduce((sum, uid) => {
          const acc = globalProgressByUid.get(uid);
          return sum + (acc ?
            acc.completedModuleIds.size + acc.completedSectionIds.size :
            0);
        }, 0);
    } catch (error) {
      report.errors.push(error instanceof Error ?
        error.message :
        String(error));
    }

    churchReports.push(report);
  }

  const finishedAt = new Date().toISOString();
  const report: RunReport = {
    startedAt,
    finishedAt,
    dryRun: options.dryRun,
    databaseId: options.databaseId,
    churchesProcessed: churchDocs.length,
    identitiesWritten,
    avatarBlobsMigrated,
    churches: churchReports,
    conflictCount: conflicts.length,
  };
  return {report, conflicts};
}

/**
 * Builds the new `churches/{cid}/members/{oldDocId}` doc for one old row.
 * Linked rows get display* fields cached from the merged identity (§9.2);
 * unlinked rows keep their own raw fields as authoritative (§9.3).
 * @param {ResolvedRow} row The old row being migrated.
 * @param {MergedIdentity | null | undefined} identity The row's merged
 * identity, or null/undefined for an unlinked row.
 * @return {DocData} The membership document to write.
 */
function buildMembershipDoc(
  row: ResolvedRow,
  identity: MergedIdentity | null | undefined,
): DocData {
  const data = row.data;
  const base: DocData = {
    uid: row.linkedUid ?? "",
    linkedUid: row.linkedUid,
    category: String(data["category"] ?? ""),
    familyId: String(data["familyId"] ?? ""),
    churchGroupIds: Array.isArray(data["churchGroupIds"]) ?
      data["churchGroupIds"] :
      [],
    membershipCurrentStatus: String(data["membershipCurrentStatus"] ?? ""),
    membershipNotes: String(data["membershipNotes"] ?? ""),
    additionalNotes: String(data["additionalNotes"] ?? ""),
    solemnizedBaptism: data["solemnizedBaptism"] === true,
    baptismDate: data["baptismDate"] ?? null,
    baptismCertificateNumber: String(data["baptismCertificateNumber"] ?? ""),
    baptismChurchName: String(data["baptismChurchName"] ?? ""),
    baptismPastorName: String(data["baptismPastorName"] ?? ""),
    marriageSolemnizationChurchType:
      String(data["marriageSolemnizationChurchType"] ?? ""),
    marriageSolemnizationChurchName:
      String(data["marriageSolemnizationChurchName"] ?? ""),
    financialStabilityRating: Number(data["financialStabilityRating"] ?? 0),
    financialSupportRequired: data["financialSupportRequired"] === true,
    role: String(data["role"] ?? "user"),
    approved: data["approved"] === true,
    joinedAt: data["createdAt"] ?? admin.firestore.FieldValue.serverTimestamp(),
    schemaVersion: 1,
    identitySyncedAt: row.linkedUid ?
      admin.firestore.FieldValue.serverTimestamp() :
      null,
  };

  if (identity) {
    // Linked: display* is a cache of the merged identity (§9.2).
    return {
      ...base,
      displayName: identity.name,
      displayEmail: identity.email,
      displayPhone: identity.phone,
      displayPhotoUrl: String(data["profilePhotoUrl"] ?? ""),
      displayDob: identity.dob,
      displayGender: identity.gender,
      displayWeddingDay: identity.weddingDay,
      displayMaritalStatus: identity.maritalStatus,
      displayEducationalQualification: identity.educationalQualification,
      displayTalentsAndGifts: identity.talentsAndGifts,
      displayLocation: identity.location,
      displayAddress: identity.address,
    };
  }

  // Unlinked: this row's own raw fields are authoritative (§9.3) — no
  // cross-church merge, since there is no person-level identity to merge.
  const phone = String(data["phone"] ?? "").trim() ||
    String(data["contact"] ?? "").trim();
  return {
    ...base,
    displayName: String(data["name"] ?? ""),
    displayEmail: String(data["email"] ?? "").trim().toLowerCase(),
    displayPhone: phone,
    displayPhotoUrl: String(data["profilePhotoUrl"] ?? ""),
    displayDob: data["dob"] ?? null,
    displayGender: String(data["gender"] ?? ""),
    displayWeddingDay: data["weddingDay"] ?? null,
    displayMaritalStatus: String(data["maritalStatus"] ?? ""),
    displayEducationalQualification:
      String(data["educationalQualification"] ?? ""),
    displayTalentsAndGifts: Array.isArray(data["talentsAndGifts"]) ?
      data["talentsAndGifts"] :
      [],
    displayLocation: String(data["location"] ?? ""),
    displayAddress: String(data["address"] ?? ""),
  };
}

/**
 * Tags every untagged `learning_results` row in a church with its module
 * source (§6 Phase 2). Idempotent — already-tagged rows are skipped.
 * @param {Firestore} firestore Target Firestore instance.
 * @param {string} churchId Church to process.
 * @param {boolean} dryRun When true, counts what would be tagged without
 * writing.
 * @return {Promise<{tagged: number, unresolved: number}>} Counts of rows
 * tagged and rows whose module couldn't be resolved.
 */
async function tagLearningResults(
  firestore: Firestore,
  churchId: string,
  dryRun: boolean,
): Promise<{tagged: number; unresolved: number}> {
  const moduleIndex = await loadChurchModuleIndex(firestore, churchId);
  const resultsSnapshot = await firestore
    .collection("churches").doc(churchId).collection("learning_results")
    .get();

  let tagged = 0;
  let unresolved = 0;
  for (const doc of resultsSnapshot.docs) {
    if (doc.data()["source"]) continue; // already tagged (idempotent re-run)
    const moduleId = String(doc.data()["moduleId"] ?? "");
    const source = moduleId ?
      resolveModuleSource(moduleIndex, moduleId) :
      null;
    if (!source) {
      unresolved += 1;
      continue;
    }
    if (!dryRun) await doc.ref.update({source});
    tagged += 1;
  }
  return {tagged, unresolved};
}

/**
 * Copies every `groups/{gid}/users` row forward to `groups/{gid}/
 * groupMembers`, re-keyed by resolved uid (§5.1/§9.4). Non-destructive —
 * the old `users` rows are left in place.
 * @param {Firestore} firestore Target Firestore instance.
 * @param {admin.auth.Auth} auth Admin Auth instance, used to resolve
 * uid/email-keyed rows.
 * @param {string} churchId Church to process.
 * @param {boolean} dryRun When true, counts what would be rekeyed without
 * writing.
 * @return {Promise<{rekeyed: number, unresolved: number}>} Counts of rows
 * rekeyed and rows whose uid couldn't be resolved.
 */
async function rekeyGroupMembers(
  firestore: Firestore,
  auth: admin.auth.Auth,
  churchId: string,
  dryRun: boolean,
): Promise<{rekeyed: number; unresolved: number}> {
  const groupsSnapshot = await firestore
    .collection("churches").doc(churchId).collection("groups").get();

  let rekeyed = 0;
  let unresolved = 0;
  for (const groupDoc of groupsSnapshot.docs) {
    const membersSnapshot = await groupDoc.ref.collection("users").get();
    for (const memberDoc of membersSnapshot.docs) {
      const data = memberDoc.data();
      const rawUid = String(data["uid"] ?? "").trim();
      const email = String(data["email"] ?? "").trim().toLowerCase();

      let resolvedUid: string | null = null;
      if (rawUid && await isRealAuthUid(auth, rawUid)) {
        resolvedUid = rawUid;
      } else if (await isRealAuthUid(auth, memberDoc.id)) {
        resolvedUid = memberDoc.id;
      } else if (email) {
        resolvedUid = await resolveUidByEmail(auth, email);
      }

      if (!resolvedUid) {
        unresolved += 1;
        continue;
      }

      if (!dryRun) {
        await groupDoc.ref.collection("groupMembers").doc(resolvedUid).set({
          ...data,
          uid: resolvedUid,
        });
      }
      rekeyed += 1;
    }
  }
  return {rekeyed, unresolved};
}
