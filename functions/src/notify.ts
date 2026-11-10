import * as admin from "firebase-admin";
import {logger} from "firebase-functions";
import {firestoreDb} from "./firestoreDb";

/**
 * Reads a value as a trimmed string, or "" when it is absent or not one.
 * @param {unknown} value Raw value.
 * @return {string} The trimmed string.
 */
function readUnknownString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/** A device's token together with the doc it came from, so it can be pruned. */
export type RegisteredDevice = {
  uid: string;
  token: string;
  ref: admin.firestore.DocumentReference;
};

/**
 * Every approved member's person-uid for one church.
 *
 * Membership is read at send time rather than trusted from a client-held FCM
 * topic subscription. A subscription is a cache of membership, and caches
 * drift — someone leaves a church, is revoked, or reinstalls, and the device
 * keeps receiving. This cannot drift.
 * @param {string} churchId The church to read.
 * @return {Promise<string[]>} Distinct person uids.
 */
export async function approvedMemberUids(churchId: string): Promise<string[]> {
  const snapshot = await firestoreDb()
    .collection("churches").doc(churchId)
    .collection("members")
    .where("approved", "==", true)
    .get();
  return distinctUids(snapshot.docs);
}

/**
 * Approved members of one church who belong to one of its groups.
 * @param {string} churchId The church to read.
 * @param {string} groupId The church group.
 * @return {Promise<string[]>} Distinct person uids.
 */
export async function churchGroupMemberUids(
  churchId: string,
  groupId: string,
): Promise<string[]> {
  const snapshot = await firestoreDb()
    .collection("churches").doc(churchId)
    .collection("members")
    .where("approved", "==", true)
    .where("churchGroupIds", "array-contains", groupId)
    .get();
  return distinctUids(snapshot.docs);
}

/**
 * Everyone who is an approved member of at least one church — the audience
 * for cross-church content, which belongs to no single church. Owner's call,
 * 2026-11-09: not every registered device, only people actually inside a
 * church.
 * @return {Promise<string[]>} Distinct person uids.
 */
export async function allApprovedMemberUids(): Promise<string[]> {
  // Deliberately a union of per-church queries rather than
  // `collectionGroup("members").where("approved", "==", true)`. That reads
  // better but needs a collection-group index exemption on `approved` which
  // this project does not have, so it fails FAILED_PRECONDITION — and a
  // notification that throws on the way to being addressed is one nobody
  // ever learns was missed. Each per-church query uses the automatic
  // single-field index, so this works with no deploy-time dependency.
  const churches = await firestoreDb().collection("churches").listDocuments();
  const perChurch = await Promise.all(
    churches.map((church) =>
      church.collection("members").where("approved", "==", true).get(),
    ),
  );
  const uids = new Set<string>();
  perChurch.forEach((snapshot) => {
    distinctUids(snapshot.docs).forEach((uid) => uids.add(uid));
  });
  return Array.from(uids);
}

/**
 * Person uids from member docs, de-duplicated.
 *
 * `linkedUid` is the person behind a membership since the user/church
 * decoupling; the doc id is the fallback for anything written before it.
 * @param {admin.firestore.QueryDocumentSnapshot[]} docs Member docs.
 * @return {string[]} Distinct uids.
 */
export function distinctUids(
  docs: admin.firestore.QueryDocumentSnapshot[],
): string[] {
  const uids = docs
    .map((doc) => readUnknownString(doc.data()["linkedUid"]) || doc.id)
    .filter((uid) => uid.length > 0);
  return Array.from(new Set(uids));
}

/**
 * Sends one notification to every device of every listed person, and prunes
 * the devices FCM reports as gone.
 *
 * That pruning is not optional housekeeping. Topic subscriptions used to let
 * FCM drop stale tokens for us; addressing devices directly means nothing
 * does, so without this the registry fills with dead tokens that are retried
 * on every send forever.
 * @param {object} options Audience, copy and payload.
 * @param {string[]} options.uids People to reach.
 * @param {string} options.title Notification title.
 * @param {string} options.body Notification body.
 * @param {Record<string, string>} options.data Payload, including churchId.
 * @param {string} [options.excludeUid] Person to skip — usually the author.
 * @param {Function} [options.overrideFor] Per-person copy, e.g. the author's.
 * @return {Promise<{successCount: number, failureCount: number}>} Totals.
 */
export async function sendToUids(options: {
  uids: string[];
  title: string;
  body: string;
  data: Record<string, string>;
  excludeUid?: string;
  overrideFor?: (uid: string) => {title: string; body: string} | null;
}): Promise<{successCount: number; failureCount: number}> {
  const audience = options.uids.filter(
    (uid) => uid.length > 0 && uid !== options.excludeUid,
  );
  if (audience.length === 0) return {successCount: 0, failureCount: 0};

  const devices = await resolveRegisteredDevices(audience);
  const seenTokens = new Set<string>();
  const messages: admin.messaging.Message[] = [];
  const tokenOrder: string[] = [];

  for (const device of devices) {
    if (seenTokens.has(device.token)) continue;
    seenTokens.add(device.token);
    const override = options.overrideFor?.(device.uid);
    messages.push({
      token: device.token,
      notification: {
        title: override?.title ?? options.title,
        body: override?.body ?? options.body,
      },
      data: options.data,
      // `church_messages` is the channel the app creates at startup; without
      // naming it Android drops these into the default channel and they lose
      // their sound and importance. Every notification this app sends wants
      // the same treatment, so it belongs here rather than at a call site.
      android: {
        notification: {
          channelId: "church_messages",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {sound: "default"},
        },
      },
    });
    tokenOrder.push(device.token);
  }
  if (messages.length === 0) return {successCount: 0, failureCount: 0};

  const refByToken = new Map(devices.map((d) => [d.token, d.ref]));
  let successCount = 0;
  let failureCount = 0;
  const stale: admin.firestore.DocumentReference[] = [];

  for (let index = 0; index < messages.length; index += 500) {
    const slice = messages.slice(index, index + 500);
    const response = await admin.messaging().sendEach(slice);
    successCount += response.successCount;
    failureCount += response.failureCount;
    response.responses.forEach((result, offset) => {
      if (result.success) return;
      const code = result.error?.code ?? "";
      if (
        code !== "messaging/registration-token-not-registered" &&
        code !== "messaging/invalid-argument"
      ) {
        return;
      }
      const ref = refByToken.get(tokenOrder[index + offset]);
      if (ref) stale.push(ref);
    });
  }

  await pruneStaleDevices(stale);
  return {successCount, failureCount};
}

/**
 * Deletes device docs whose tokens FCM has rejected as unknown.
 * @param {admin.firestore.DocumentReference[]} refs Devices to remove.
 * @return {Promise<void>} Resolves once removed, or once the failure is
 * logged — a failed prune costs a repeat, never a missed notification.
 */
export async function pruneStaleDevices(
  refs: admin.firestore.DocumentReference[],
): Promise<void> {
  if (refs.length === 0) return;
  try {
    for (let index = 0; index < refs.length; index += 450) {
      const batch = firestoreDb().batch();
      refs.slice(index, index + 450).forEach((ref) => batch.delete(ref));
      await batch.commit();
    }
    logger.info("Pruned device registrations FCM no longer knows.", {
      count: refs.length,
    });
  } catch (error) {
    logger.warn("Could not prune stale device registrations.", {
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

/**
 * Every registered device for a set of people, with the doc each came from.
 * @param {string[]} uids The people to resolve.
 * @return {Promise<RegisteredDevice[]>} Their devices.
 */
export async function resolveRegisteredDevices(
  uids: string[],
): Promise<RegisteredDevice[]> {
  const devices: RegisteredDevice[] = [];
  const distinct = Array.from(new Set(uids)).filter((uid) => uid.length > 0);
  const chunkSize = 30; // Firestore "in" query limit.

  for (let index = 0; index < distinct.length; index += chunkSize) {
    const snapshot = await firestoreDb()
      .collectionGroup("devices")
      .where("uid", "in", distinct.slice(index, index + chunkSize))
      .get();
    snapshot.docs.forEach((doc) => {
      const uid = readUnknownString(doc.data()["uid"]);
      const token = readUnknownString(doc.data()["fcmToken"]);
      if (uid && token) devices.push({uid, token, ref: doc.ref});
    });
  }
  return devices;
}
