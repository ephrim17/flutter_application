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

// Everything else that still names a deleted person — reported, not
// touched. Deleting a prayer request or a feed post is a different
// decision from deleting the person's membership.
console.log('\nStill referencing deleted people (not touched):');
for (const [name, field] of [
  ['prayer_requests', 'userId'],
  ['feeds', 'userId'],
  ['learning_results', 'userId'],
  ['notification_requests', 'createdBy'],
]) {
  const snapshot = await churchRef.collection(name).get();
  const stale = snapshot.docs.filter((doc) => {
    const value = (doc.data() || {})[field];
    return typeof value === 'string' && value && !live.has(value);
  });
  console.log(`  ${name.padEnd(22)} ${stale.length} of ${snapshot.size}`);
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

for (const file of doomedFiles) {
  await file.delete();
}
console.log(`  ${doomedFiles.length} storage objects`);
console.log('\nDone.');
