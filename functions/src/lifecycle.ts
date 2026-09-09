import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";
import {firestoreDb} from "./firestoreDb";

/**
 * Reads a value as a trimmed string, or "" if it isn't one.
 * @param {unknown} value Raw value.
 * @return {string} The trimmed string, or "".
 */
function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * Deletes every document in a collection, in batches — Firestore does not
 * cascade-delete subcollections when their parent doc is deleted.
 * @param {FirebaseFirestore.CollectionReference} collection Collection to
 * empty.
 * @return {Promise<void>} Resolves once every document is gone.
 */
async function deleteCollection(
  collection: FirebaseFirestore.CollectionReference,
): Promise<void> {
  const firestore = collection.firestore;
  for (;;) {
    const snapshot = await collection.limit(200).get();
    if (snapshot.empty) return;
    const batch = firestore.batch();
    for (const doc of snapshot.docs) batch.delete(doc.ref);
    await batch.commit();
  }
}

/**
 * Deletes every `groupMembers/{uid}` row for a person across every group in
 * one church — there is no collectionGroup shortcut scoped to a single
 * church, so this enumerates that church's groups (always a small list).
 * @param {FirebaseFirestore.Firestore} firestore Firestore instance.
 * @param {string} churchId Church to search.
 * @param {string} uid Person to remove.
 * @return {Promise<void>} Resolves once every matching row is deleted.
 */
async function removeFromChurchGroups(
  firestore: FirebaseFirestore.Firestore,
  churchId: string,
  uid: string,
): Promise<void> {
  const groupsSnapshot = await firestore
    .collection("churches").doc(churchId).collection("groups").get();
  const batch = firestore.batch();
  let hasDeletes = false;
  for (const groupDoc of groupsSnapshot.docs) {
    const memberRef = groupDoc.ref.collection("groupMembers").doc(uid);
    const memberDoc = await memberRef.get();
    if (memberDoc.exists) {
      batch.delete(memberRef);
      hasDeletes = true;
    }
  }
  if (hasDeletes) await batch.commit();
}

/**
 * Removes a person's email from a church's admin allowlist, best-effort —
 * leaving a church (or deleting the account) must not leave them able to
 * pass `isChurchAdmin(churchId)` for a church they're no longer a member
 * of (§9.1: role/allowlist membership is never re-derived from anything
 * else, so it has to be cleaned up explicitly here). A no-op if they
 * weren't in it, or if the config doc doesn't exist.
 * @param {FirebaseFirestore.Firestore} firestore Firestore instance.
 * @param {string} churchId Church whose admin list to update.
 * @param {string} email The person's email, already lowercased.
 * @return {Promise<void>} Resolves once the attempt completes.
 */
async function removeFromChurchAdmins(
  firestore: FirebaseFirestore.Firestore,
  churchId: string,
  email: string,
): Promise<void> {
  if (!email) return;
  const configRef = firestore
    .collection("churches").doc(churchId).collection("config").doc("app");
  try {
    const configDoc = await configRef.get();
    if (!configDoc.exists) return;
    const admins = Array.isArray(configDoc.data()?.admins) ?
      configDoc.data()?.admins as unknown[] :
      [];
    // arrayRemove needs the exact stored value, which may not be
    // lowercased the same way `email` already is — find it by
    // case-insensitive match rather than assuming the casing lines up.
    const storedValue = admins.find(
      (value) => readString(value).toLowerCase() === email,
    );
    if (storedValue === undefined) return;
    await configRef.update({
      admins: admin.firestore.FieldValue.arrayRemove(storedValue),
    });
  } catch (error) {
    logger.warn("Best-effort admin-list removal failed.", {
      churchId,
      email,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

/**
 * Deletes every Storage object under a prefix, best-effort — failures are
 * logged, not thrown, since a missing bucket/prefix is not fatal to the
 * surrounding lifecycle operation.
 * @param {string} prefix Storage path prefix to delete.
 * @return {Promise<void>} Resolves once the attempt completes.
 */
async function deleteStoragePrefix(prefix: string): Promise<void> {
  try {
    await admin.storage().bucket().deleteFiles({prefix});
  } catch (error) {
    logger.warn("Best-effort storage prefix delete failed.", {
      prefix,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

/**
 * Leave church (§6 Phase 7): deletes the caller's own membership and group
 * rows in one church only. Identity, favorites, reading plans, Church Tree
 * progress and streak all live on users/{uid} and are untouched.
 */
export const leaveChurch = onCall(
  {region: "us-central1"},
  async (request) => {
    const uid = readString(request.auth?.uid);
    if (!uid) throw new HttpsError("unauthenticated", "Sign-in required.");
    const email = readString(request.auth?.token.email).toLowerCase();
    const churchId = readString(request.data?.churchId);
    if (!churchId) {
      throw new HttpsError("invalid-argument", "Missing churchId.");
    }

    const firestore = firestoreDb();
    const memberRef = firestore
      .collection("churches").doc(churchId)
      .collection("members").doc(uid);

    await deleteCollection(memberRef.collection("learning_progress"));
    await removeFromChurchGroups(firestore, churchId, uid);
    await removeFromChurchAdmins(firestore, churchId, email);
    await memberRef.delete();

    logger.info("Member left church.", {uid, churchId});
    return {success: true};
  },
);

/**
 * Delete church (§6 Phase 7, super admin only): recursively deletes the
 * entire churches/{churchId} subtree and its Storage blobs. Users survive
 * — nothing outside that subtree is touched.
 */
export const deleteChurch = onCall(
  {region: "us-central1"},
  async (request) => {
    const email = readString(request.auth?.token.email).toLowerCase();
    if (!email) throw new HttpsError("unauthenticated", "Sign-in required.");
    const churchId = readString(request.data?.churchId);
    if (!churchId) {
      throw new HttpsError("invalid-argument", "Missing churchId.");
    }

    const firestore = firestoreDb();
    const superAdminSnapshot = await firestore
      .collection("superAdmins")
      .where("email", "==", email)
      .where("enabled", "==", true)
      .limit(1)
      .get();
    if (superAdminSnapshot.empty) {
      throw new HttpsError(
        "permission-denied", "Super admin authorization required.",
      );
    }

    const churchRef = firestore.collection("churches").doc(churchId);
    await firestore.recursiveDelete(churchRef);
    await deleteStoragePrefix(`churches/${churchId}/`);

    logger.info("Deleted church.", {churchId, deletedBy: email});
    return {success: true};
  },
);

const recentAuthWindowSeconds = 5 * 60;

/**
 * Delete account (§6 Phase 7): deletes users/{uid} and its subcollections,
 * every membership (and that membership's own learning_progress and
 * group rows) across every church, the person's Storage blobs, then the
 * Auth user itself. Requires the caller's ID token to be fresh (the client
 * calls reauthenticateWithCredential immediately before this, matching the
 * password re-entry the previous client-only flow already required) —
 * this is the server-side half of that same guarantee.
 */
export const deleteAccount = onCall(
  {region: "us-central1"},
  async (request) => {
    const uid = readString(request.auth?.uid);
    if (!uid) throw new HttpsError("unauthenticated", "Sign-in required.");

    const authTime = request.auth?.token.auth_time;
    const nowSeconds = Date.now() / 1000;
    if (
      typeof authTime !== "number" ||
      nowSeconds - authTime > recentAuthWindowSeconds
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Please re-enter your password and try again.",
      );
    }

    const email = readString(request.auth?.token.email).toLowerCase();
    const firestore = firestoreDb();
    const membersSnapshot = await firestore
      .collectionGroup("members")
      .where("uid", "==", uid)
      .get();

    for (const memberDoc of membersSnapshot.docs) {
      const churchId = memberDoc.ref.parent.parent?.id;
      await deleteCollection(memberDoc.ref.collection("learning_progress"));
      if (churchId) {
        await removeFromChurchGroups(firestore, churchId, uid);
        await removeFromChurchAdmins(firestore, churchId, email);
      }
      await memberDoc.ref.delete();
      if (churchId) {
        await deleteStoragePrefix(`churches/${churchId}/users/${uid}/profile/`);
      }
    }

    const userRef = firestore.collection("users").doc(uid);
    await deleteCollection(userRef.collection("readingPlans"));
    await deleteCollection(userRef.collection("favorites"));
    await deleteCollection(userRef.collection("devices"));
    await deleteCollection(userRef.collection("learning_progress"));
    await userRef.delete();

    await deleteStoragePrefix(`users/${uid}/profile/`);

    await admin.auth().deleteUser(uid);

    logger.info("Deleted account.", {
      uid,
      churchesLeft: membersSnapshot.size,
    });
    return {success: true};
  },
);
