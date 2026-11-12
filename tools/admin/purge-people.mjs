// Destructive. Removes the people-shaped records left behind when accounts
// were deleted: church membership rows, their directory mirror, families
// nobody is in any more, orphaned users/{uid} documents and the Storage
// objects filed under them.
//
// "Who still exists" is decided by Firebase Auth, not by a list typed here:
// an account that is gone cannot own a membership. Run purge-auth.mjs
// first, then this.
//
// Dry run by default.
//
//   node tools/admin/purge-people.mjs --key /path/key.json --church tnbm
//   node tools/admin/purge-people.mjs --key /path/key.json --church tnbm \
//     --backup ~/church-tree-backup-2026-11-12 --apply --confirm PURGE-PEOPLE

import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { admin, parseArgs, listAllAuthUsers } from './_lib.mjs';

const argv = process.argv;
const args = parseArgs(argv);
const church = argv.includes('--church') ? argv[argv.indexOf('--church') + 1] : null;
const backup = argv.includes('--backup') ? argv[argv.indexOf('--backup') + 1] : null;

if (!church) {
  console.error('Give --church <churchId>.');
  process.exit(1);
}

const { db, auth, bucket } = admin();
const churchRef = db.collection('churches').doc(church);

const accounts = await listAllAuthUsers(auth);
const live = new Set(accounts.map((u) => u.uid));
console.log(`Accounts that still exist (${accounts.length}):`);
for (const user of accounts) console.log(`  ${user.email}`);

const alive = (docId, data) =>
  live.has(docId) ||
  live.has(data?.uid ?? '') ||
  live.has(data?.userId ?? '');

// Membership rows and the directory mirror of them.
const doomedDocs = [];
for (const name of ['members', 'memberDirectory']) {
  const snapshot = await churchRef.collection(name).get();
  const doomed = snapshot.docs.filter((doc) => !alive(doc.id, doc.data()));
  console.log(`\nchurches/${church}/${name}: ${doomed.length} of ${snapshot.size} to delete`);
  for (const doc of doomed) {
    const data = doc.data() || {};
    console.log(`  ${data.displayName || data.name || '(no name)'}`);
  }
  doomedDocs.push(...doomed.map((d) => d.ref));
}

// A family survives only if a surviving member still points at it. Its own
// head field is not enough: the head is usually an account, and this runs
// after those have gone.
const keptFamilyIds = new Set();
const members = await churchRef.collection('members').get();
for (const doc of members.docs) {
  const data = doc.data() || {};
  if (alive(doc.id, data) && typeof data.familyId === 'string' && data.familyId) {
    keptFamilyIds.add(data.familyId);
  }
}
const families = await churchRef.collection('families').get();
const doomedFamilies = families.docs.filter((doc) => !keptFamilyIds.has(doc.id));
console.log(`\nchurches/${church}/families: ${doomedFamilies.length} of ${families.size} to delete`);
for (const doc of doomedFamilies) {
  const data = doc.data() || {};
  console.log(`  ${doc.id}  head: ${data.familyHead || data.label || '(none)'}`);
}
doomedDocs.push(...doomedFamilies.map((d) => d.ref));

// Person documents with no account behind them.
const users = await db.collection('users').get();
const doomedUsers = users.docs.filter((doc) => !live.has(doc.id));
console.log(`\nusers: ${doomedUsers.length} of ${users.size} to delete`);
for (const doc of doomedUsers) {
  console.log(`  ${(doc.data() || {}).email || '(no email)'}  ${doc.id}`);
}

// ...and their Storage objects, filed under users/{uid}/.
const [userFiles] = await bucket.getFiles({ prefix: 'users/' });
const doomedFiles = userFiles.filter((file) => {
  const uid = file.name.split('/')[1];
  return uid && !live.has(uid) && !file.name.endsWith('/');
});
console.log(`\nStorage under users/: ${doomedFiles.length} objects to delete`);
for (const file of doomedFiles) console.log(`  ${file.name}`);

// Content a deleted person wrote. Off by default: deleting someone's
// prayer request is a different decision from deleting their membership,
// so --purge-content has to ask for it.
const contentCollections = [
  ['prayer_requests', 'userId'],
  ['feeds', 'userId'],
  ['learning_results', 'userId'],
  ['notification_requests', 'createdBy'],
];

const purgeContent = args.flags.has('purge-content');
const doomedContent = [];
console.log(
  purgeContent
    ? '\nContent written by deleted people (to delete):'
    : '\nStill referencing deleted people (not touched — pass --purge-content):',
);
for (const [name, field] of contentCollections) {
  const snapshot = await churchRef.collection(name).get();
  const stale = snapshot.docs.filter((doc) => {
    const value = (doc.data() || {})[field];
    return typeof value === 'string' && value && !live.has(value);
  });
  console.log(`  ${name.padEnd(22)} ${stale.length} of ${snapshot.size}`);
  if (purgeContent) doomedContent.push(...stale.map((d) => d.ref));
}

// A feed post's image is filed under the post id. Deleting the document
// alone would leave the picture in the bucket with nothing pointing at it.
const doomedImages = [];
if (purgeContent) {
  const postIds = new Set(
    doomedContent.filter((ref) => ref.parent.id === 'feeds').map((ref) => ref.id),
  );
  const [feedFiles] = await bucket.getFiles({ prefix: `churches/${church}/feed/` });
  doomedImages.push(
    ...feedFiles.filter((file) => {
      const name = file.name.split('/').pop() || '';
      return postIds.has(name.replace(/\.[a-z0-9]+$/i, ''));
    }),
  );
  console.log(`  feed images            ${doomedImages.length}`);
}

// Group rosters are keyed by uid, so a deleted account leaves a row that
// names nobody.
const doomedRoster = [];
if (purgeContent) {
  const groups = await churchRef.collection('groups').get();
  for (const group of groups.docs) {
    const roster = await group.ref.collection('groupMembers').get();
    doomedRoster.push(
      ...roster.docs
        .filter((doc) => !alive(doc.id, doc.data()))
        .map((doc) => doc.ref),
    );
  }
  console.log(`  group roster rows      ${doomedRoster.length}`);
}

// Attendance is different: the gathering happened, and the record carries
// counts and notes of its own. The deleted people are pruned out of the
// present list rather than the service being deleted.
const attendanceEdits = [];
if (purgeContent) {
  const services = await churchRef.collection('services').get();
  for (const service of services.docs) {
    const present = (service.data() || {}).present;
    if (!Array.isArray(present)) continue;
    const kept = present.filter((uid) => typeof uid === 'string' && live.has(uid));
    if (kept.length !== present.length) {
      attendanceEdits.push({ ref: service.ref, kept, removed: present.length - kept.length });
    }
  }
  const removed = attendanceEdits.reduce((sum, edit) => sum + edit.removed, 0);
  console.log(`  attendance entries     ${removed} pruned from ${attendanceEdits.length} service(s)`);
}

if (!args.apply) {
  console.log('\nDry run. Nothing was deleted. Add --apply --confirm PURGE-PEOPLE to go ahead.');
  process.exit(0);
}
if (args.confirm !== 'PURGE-PEOPLE') {
  console.error('\n--confirm PURGE-PEOPLE is required.');
  process.exit(1);
}
if (!backup || !existsSync(join(backup, 'manifest.json'))) {
  console.error('\nNo backup manifest. Run backup.mjs first.');
  process.exit(1);
}

console.log('\nDeleting.\n');
for (const ref of doomedDocs) {
  await db.recursiveDelete(ref);
}
console.log(`  ${doomedDocs.length} church documents`);

for (const doc of doomedUsers) {
  await db.recursiveDelete(doc.ref);
}
console.log(`  ${doomedUsers.length} user documents`);

for (const file of [...doomedFiles, ...doomedImages]) {
  await file.delete();
}
console.log(`  ${doomedFiles.length + doomedImages.length} storage objects`);

for (const ref of [...doomedContent, ...doomedRoster]) {
  // recursiveDelete, because a feed post owns a reactions subcollection.
  await db.recursiveDelete(ref);
}
if (purgeContent) {
  console.log(`  ${doomedContent.length} content documents, ${doomedRoster.length} roster rows`);
  for (const edit of attendanceEdits) {
    await edit.ref.update({ present: edit.kept });
  }
  console.log(`  ${attendanceEdits.length} attendance record(s) pruned`);
}
console.log('\nDone.');
