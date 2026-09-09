import * as crypto from "crypto";
import * as admin from "firebase-admin";

const oldAvatarPathPattern =
  /^churches\/[^/]+\/users\/([^/]+)\/profile\/(.+)$/;

/**
 * Extracts the Storage object path from a Firebase download URL
 * (`https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<encoded-path>
 * ?alt=media&token=...`), or null if it isn't one.
 * @param {string} url A `profilePhotoUrl` value.
 * @return {string | null} The decoded object path, or null.
 */
function objectPathFromDownloadUrl(url: string): string | null {
  const match = /\/o\/([^?]+)/.exec(url);
  if (!match) return null;
  try {
    return decodeURIComponent(match[1]);
  } catch {
    return null;
  }
}

/**
 * Builds a permanent Firebase Storage download URL for an object, given a
 * download token already set as that object's `firebaseStorageDownloadTokens`
 * metadata.
 * @param {string} bucketName Storage bucket name.
 * @param {string} objectPath Object path within the bucket.
 * @param {string} token The object's download token.
 * @return {string} The download URL.
 */
function downloadUrlFor(
  bucketName: string,
  objectPath: string,
  token: string,
): string {
  const encodedPath = encodeURIComponent(objectPath);
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/` +
    `${encodedPath}?alt=media&token=${token}`;
}

/**
 * Moves a person's avatar off the old per-church Storage path
 * (`churches/{cid}/users/{uid}/profile/...`) onto the new
 * person-owned one (`users/{uid}/profile/...`) — §6 Phase 4's
 * deferred "copy blobs, rewrite profilePhotoUrl" item. A no-op (returns
 * the URL unchanged) for anything not matching the old pattern — already
 * on the new path, an external URL, or empty.
 * @param {admin.storage.Storage} storage Admin Storage instance.
 * @param {string} uid The person's uid — the copy only proceeds if the
 * old path's own uid segment matches, as a safety check.
 * @param {string} profilePhotoUrl The identity's current photo URL.
 * @param {boolean} dryRun When true, reports what would happen without
 * copying anything.
 * @return {Promise<{url: string, copied: boolean}>} The (possibly
 * rewritten) URL, and whether a copy did (or would) happen.
 */
export async function migrateAvatarBlob(
  storage: admin.storage.Storage,
  uid: string,
  profilePhotoUrl: string,
  dryRun: boolean,
): Promise<{url: string; copied: boolean}> {
  if (!profilePhotoUrl) return {url: profilePhotoUrl, copied: false};

  const oldPath = objectPathFromDownloadUrl(profilePhotoUrl);
  if (!oldPath) return {url: profilePhotoUrl, copied: false};

  const match = oldAvatarPathPattern.exec(oldPath);
  if (!match || match[1] !== uid) return {url: profilePhotoUrl, copied: false};

  const bucket = storage.bucket();
  const fileName = match[2];
  const newPath = `users/${uid}/profile/${fileName}`;
  const oldFile = bucket.file(oldPath);

  const [exists] = await oldFile.exists();
  if (!exists) return {url: profilePhotoUrl, copied: false};

  if (dryRun) return {url: profilePhotoUrl, copied: true};

  const token = crypto.randomUUID();
  await oldFile.copy(bucket.file(newPath));
  await bucket.file(newPath).setMetadata({
    metadata: {firebaseStorageDownloadTokens: token},
  });

  return {url: downloadUrlFor(bucket.name, newPath, token), copied: true};
}
