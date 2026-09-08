import * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions";

/**
 * Reads a Firestore field as a trimmed string, or "" if absent/not a
 * string.
 * @param {unknown} value Raw Firestore field value.
 * @return {string} The trimmed string, or "".
 */
function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

const cachedIdentityFields = [
  "name", "email", "phone", "profilePhotoUrl", "dob", "gender",
  "weddingDay", "maritalStatus", "educationalQualification",
  "talentsAndGifts", "location", "address",
] as const;

/**
 * Applies one update to every document in a query snapshot, chunked at
 * Firestore's 500-writes-per-batch limit.
 * @param {FirebaseFirestore.Firestore} firestore Firestore instance.
 * @param {FirebaseFirestore.QuerySnapshot} snapshot Docs to update.
 * @param {Record<string, unknown>} data Fields to set (merged).
 * @return {Promise<number>} How many documents were updated.
 */
async function batchedMerge(
  firestore: FirebaseFirestore.Firestore,
  snapshot: FirebaseFirestore.QuerySnapshot,
  data: Record<string, unknown>,
): Promise<number> {
  const docs = snapshot.docs;
  for (let index = 0; index < docs.length; index += 500) {
    const batch = firestore.batch();
    for (const doc of docs.slice(index, index + 500)) {
      batch.set(doc.ref, data, {merge: true});
    }
    await batch.commit();
  }
  return docs.length;
}

/**
 * One `onDocumentWritten('users/{uid}')` function replacing every
 * client-side denormalisation write (Phase 6, §6): refreshes the
 * `display*` cache on every linked membership, and the `userName`/
 * `userPhoto`(`Url`) denormalised on that person's feeds, globalFeeds,
 * groupMembers, faith_engagement and learning_results. Short-circuits when
 * none of the cached identity fields actually changed, and skips unlinked
 * membership rows entirely (§9.2 — an unlinked row's display* is its own
 * authoritative data, never a cache to refresh).
 */
export const fanOutIdentityChanges = onDocumentWritten(
  {
    document: "users/{uid}",
    region: "us-central1",
  },
  async (event) => {
    const uid = event.params.uid;
    const after = event.data?.after.exists ? event.data.after.data() : null;
    if (!after) return; // Deletion is handled by Phase 7's lifecycle path.

    const before = event.data?.before.exists ?
      event.data.before.data() :
      null;

    const changedFields = cachedIdentityFields.filter((field) => {
      const beforeValue = before?.[field];
      const afterValue = after[field];
      return JSON.stringify(beforeValue ?? null) !==
        JSON.stringify(afterValue ?? null);
    });
    if (before && changedFields.length === 0) return;

    const firestore = admin.firestore();
    const name = readString(after["name"]);
    const photoUrl = readString(after["profilePhotoUrl"]);

    try {
      const membersSnapshot = await firestore
        .collectionGroup("members")
        .where("uid", "==", uid)
        .get();
      const linkedMembers = membersSnapshot.docs.filter(
        (doc) => readString(doc.data()["linkedUid"]) === uid,
      );
      let membershipsUpdated = 0;
      for (let index = 0; index < linkedMembers.length; index += 500) {
        const batch = firestore.batch();
        for (const doc of linkedMembers.slice(index, index + 500)) {
          batch.set(doc.ref, {
            displayName: name,
            displayEmail: readString(after["email"]).toLowerCase(),
            displayPhone: readString(after["phone"]),
            displayPhotoUrl: photoUrl,
            displayDob: after["dob"] ?? null,
            displayGender: readString(after["gender"]),
            displayWeddingDay: after["weddingDay"] ?? null,
            displayMaritalStatus: readString(after["maritalStatus"]),
            displayEducationalQualification:
              readString(after["educationalQualification"]),
            displayTalentsAndGifts:
              Array.isArray(after["talentsAndGifts"]) ?
                after["talentsAndGifts"] :
                [],
            displayLocation: readString(after["location"]),
            displayAddress: readString(after["address"]),
            identitySyncedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        }
        await batch.commit();
        membershipsUpdated += Math.min(
          500, linkedMembers.length - index,
        );
      }

      // The name/photo-only denormalisations below only need refreshing
      // when one of those two specifically changed — not e.g. a phone or
      // address edit, which none of these collections display.
      const nameOrPhotoChanged = changedFields.includes("name") ||
        changedFields.includes("profilePhotoUrl");
      let feedsUpdated = 0;
      let globalFeedsUpdated = 0;
      let groupMembersUpdated = 0;
      let faithEngagementUpdated = 0;
      let learningResultsUpdated = 0;

      if (nameOrPhotoChanged) {
        const [
          feedsSnapshot,
          globalFeedsSnapshot,
          groupMembersSnapshot,
          faithEngagementSnapshot,
          learningResultsSnapshot,
        ] = await Promise.all([
          firestore.collectionGroup("feeds")
            .where("userId", "==", uid).get(),
          firestore.collection("globalFeeds")
            .where("userId", "==", uid).get(),
          firestore.collectionGroup("groupMembers")
            .where("uid", "==", uid).get(),
          firestore.collectionGroup("faith_engagement")
            .where("userId", "==", uid).get(),
          firestore.collectionGroup("learning_results")
            .where("userId", "==", uid).get(),
        ]);

        feedsUpdated = await batchedMerge(firestore, feedsSnapshot, {
          userName: name, userPhoto: photoUrl,
        });
        globalFeedsUpdated =
          await batchedMerge(firestore, globalFeedsSnapshot, {
            userName: name, userPhoto: photoUrl,
          });
        groupMembersUpdated =
          await batchedMerge(firestore, groupMembersSnapshot, {
            name: name, profilePhotoUrl: photoUrl,
          });
        faithEngagementUpdated =
          await batchedMerge(firestore, faithEngagementSnapshot, {
            userName: name, userPhotoUrl: photoUrl,
          });
        learningResultsUpdated =
          await batchedMerge(firestore, learningResultsSnapshot, {
            userName: name,
          });
      }

      logger.info("Fanned out identity change.", {
        uid,
        changedFields,
        membershipsUpdated,
        feedsUpdated,
        globalFeedsUpdated,
        groupMembersUpdated,
        faithEngagementUpdated,
        learningResultsUpdated,
      });
    } catch (error) {
      logger.error("Failed to fan out identity change.", {
        uid,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  },
);
