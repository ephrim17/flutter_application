import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";

export const setFeedPostGlobal = onCall(
  {region: "us-central1"},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to manage global feed posts.",
      );
    }

    const churchId = readString(request.data?.churchId);
    const postId = readString(request.data?.postId);
    const makeGlobal = request.data?.isGlobal === true;
    if (!churchId || !postId) {
      throw new HttpsError(
        "invalid-argument",
        "Church ID and post ID are required.",
      );
    }

    let email = readString(request.auth?.token.email).toLowerCase();
    if (!email) {
      const user = await admin.auth().getUser(uid);
      email = readString(user.email).toLowerCase();
    }
    if (!email) {
      throw new HttpsError(
        "permission-denied",
        "Only church admins can manage global feed posts.",
      );
    }

    const firestore = admin.firestore();
    const configRef = firestore
      .collection("churches")
      .doc(churchId)
      .collection("config")
      .doc("app");
    const configSnapshot = await configRef.get();
    const config = configSnapshot.data() ?? {};
    const admins = Array.isArray(config.admins) ?
      config.admins.map((value) => readString(value).toLowerCase()) :
      [];
    if (!admins.includes(email)) {
      throw new HttpsError(
        "permission-denied",
        "Only church admins can manage global feed posts.",
      );
    }

    const features = isRecord(config.features) ? config.features : {};
    if (makeGlobal && features.globalFeedEnabled !== true) {
      throw new HttpsError(
        "failed-precondition",
        "Global feeds are not enabled for this church.",
      );
    }

    const localPostRef = firestore
      .collection("churches")
      .doc(churchId)
      .collection("feeds")
      .doc(postId);
    const localSnapshot = await localPostRef.get();
    const post = localSnapshot.data();
    if (!post) {
      throw new HttpsError(
        "not-found",
        "The selected feed post was not found.",
      );
    }

    const globalPostRef = firestore
      .collection("globalFeeds")
      .doc(`${churchId}_${postId}`);
    const now = admin.firestore.FieldValue.serverTimestamp();
    const batch = firestore.batch();

    if (!makeGlobal) {
      batch.update(localPostRef, {
        isGlobal: false,
        updatedAt: now,
      });
      batch.delete(globalPostRef);
      await batch.commit();
      return {isGlobal: false};
    }

    batch.update(localPostRef, {
      isGlobal: true,
      updatedAt: now,
    });
    batch.set(globalPostRef, {
      userId: post.userId ?? "",
      userName: post.userName ?? "",
      userPhoto: post.userPhoto ?? null,
      churchId,
      churchName: post.churchName ?? null,
      churchPastorName: post.churchPastorName ?? null,
      sharePersonalDetails: post.sharePersonalDetails === true,
      userCategory: post.userCategory ?? null,
      userAddress: post.userAddress ?? null,
      userEmail: post.userEmail ?? null,
      userPhone: post.userPhone ?? null,
      userDob: post.userDob ?? null,
      title: post.title ?? "",
      description: post.description ?? "",
      hashtags: Array.isArray(post.hashtags) ? post.hashtags : [],
      imageUrl: post.imageUrl ?? null,
      imageUrls: Array.isArray(post.imageUrls) ? post.imageUrls : [],
      createdAt: post.createdAt ?? now,
      updatedAt: now,
      isGlobal: true,
      sourceChurchId: churchId,
      sourcePostId: postId,
      isPinned: false,
      pinnedAt: null,
    });
    await batch.commit();
    return {isGlobal: true};
  },
);

/**
 * Reads a trimmed string from an unknown callable value.
 * @param {unknown} value Raw callable value.
 * @return {string} Trimmed string or an empty string.
 */
function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * Checks whether a value is a non-null object map.
 * @param {unknown} value Value to inspect.
 * @return {boolean} Whether the value is a record.
 */
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
