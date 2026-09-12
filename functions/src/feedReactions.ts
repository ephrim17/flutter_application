import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions";
import {firestoreDatabaseIdParam} from "./firestoreDb";

/**
 * Recomputes the full `reactionSummary`/`reactionTotal` aggregate on a feed
 * post from its `reactions` subcollection and writes it back — always a
 * full recount rather than an increment/decrement, so a missed or
 * out-of-order trigger invocation can never leave the aggregate drifted
 * from the actual reaction docs.
 * @param {FirebaseFirestore.DocumentReference} postRef The parent post doc.
 * @return {Promise<void>} Resolves once the aggregate is written.
 */
async function recomputeReactionAggregate(
  postRef: FirebaseFirestore.DocumentReference,
): Promise<void> {
  const snapshot = await postRef.collection("reactions").get();
  const summary: Record<string, number> = {};
  for (const doc of snapshot.docs) {
    const emoji = doc.data()["emoji"];
    if (typeof emoji !== "string" || !emoji) continue;
    summary[emoji] = (summary[emoji] ?? 0) + 1;
  }
  try {
    await postRef.set(
      {reactionSummary: summary, reactionTotal: snapshot.size},
      {merge: true},
    );
  } catch (error) {
    // The post itself may have just been deleted (its reactions get
    // deleted separately, if at all) — not an error worth alerting on.
    logger.warn("Could not write reaction aggregate.", {
      path: postRef.path,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

/**
 * Keeps `reactionSummary`/`reactionTotal` on a church feed post in sync
 * with `churches/{churchId}/feeds/{postId}/reactions/{uid}` — the client
 * only ever writes its own reaction doc (self-only, per firestore.rules);
 * this is the only writer of the aggregate fields on the post itself,
 * which the client's write rules for `feeds/{postId}` don't otherwise
 * allow for anyone but the owner (within the edit window) or church staff.
 */
export const onChurchFeedReactionWrite = onDocumentWritten(
  {
    document: "churches/{churchId}/feeds/{postId}/reactions/{uid}",
    database: firestoreDatabaseIdParam,
    region: "us-central1",
  },
  async (event) => {
    const postRef = event.data?.after.ref.parent.parent ??
      event.data?.before.ref.parent.parent;
    if (!postRef) return;
    await recomputeReactionAggregate(postRef);
  },
);

/**
 * Same as {@link onChurchFeedReactionWrite}, for
 * `globalFeeds/{postId}/reactions/{uid}`.
 */
export const onGlobalFeedReactionWrite = onDocumentWritten(
  {
    document: "globalFeeds/{postId}/reactions/{uid}",
    database: firestoreDatabaseIdParam,
    region: "us-central1",
  },
  async (event) => {
    const postRef = event.data?.after.ref.parent.parent ??
      event.data?.before.ref.parent.parent;
    if (!postRef) return;
    await recomputeReactionAggregate(postRef);
  },
);
