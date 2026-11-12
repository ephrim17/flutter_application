// Destructive. Deletes every Firebase Auth account except the e-mail
// addresses given with --keep-email, and optionally the user documents
// those accounts owned.
//
// Dry run by default. `--apply --confirm DELETE-ACCOUNTS` is required, and
// a backup manifest, because a deleted account cannot be restored: the uid
// is gone, and every document that referenced it is orphaned.
//
//   NODE_PATH=../../functions/node_modules GOOGLE_APPLICATION_CREDENTIALS=/path/key.json \
//   node purge-auth.mjs --keep-email a@b.com --keep-email c@d.com \
//     --backup ~/church-tree-backup --apply --confirm DELETE-ACCOUNTS
//
// --keep-church-members <churchId> additionally spares anyone who is a
// member of that church, for the softer version of this.

import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { admin, parseArgs, listAllAuthUsers, churchMemberUids } from './_lib.mjs';

const argv = process.argv;
const args = parseArgs(argv);
const keepEmails = new Set(
  argv.reduce((acc, token, i) => (token === '--keep-email' ? [...acc, argv[i + 1].toLowerCase()] : acc), []),
);
const keepChurch = argv.includes('--keep-church-members')
  ? argv[argv.indexOf('--keep-church-members') + 1]
  : null;
const backup = argv.includes('--backup') ? argv[argv.indexOf('--backup') + 1] : null;
const alsoUserDocs = args.flags.has('delete-user-docs');

if (keepEmails.size === 0) {
  console.error('Give at least one --keep-email, or this would delete every account.');
  process.exit(1);
}

const { db, auth } = admin();
const users = await listAllAuthUsers(auth);
const spared = keepChurch ? await churchMemberUids(db, keepChurch) : new Set();

const keep = users.filter((u) => keepEmails.has((u.email || '').toLowerCase()) || spared.has(u.uid));
const doomed = users.filter((u) => !keep.includes(u));

console.log(`Accounts: ${users.length}   keeping ${keep.length}   deleting ${doomed.length}\n`);
console.log('Keeping:');
for (const user of keep) console.log(`  ${user.email || '(no email)'}`);
console.log('\nDeleting:');
for (const user of doomed) {
  console.log(`  ${(user.email || '(no email)').padEnd(36)} last seen ${user.metadata.lastSignInTime || 'never'}`);
}

if (!args.apply) {
  console.log('\nDry run. Nothing was deleted. Add --apply --confirm DELETE-ACCOUNTS to go ahead.');
  process.exit(0);
}
if (args.confirm !== 'DELETE-ACCOUNTS') {
  console.error('\n--confirm DELETE-ACCOUNTS is required.');
  process.exit(1);
}
if (!backup || !existsSync(join(backup, 'manifest.json'))) {
  console.error('\nNo backup manifest. Run backup.mjs first — accounts cannot be restored.');
  process.exit(1);
}

// deleteUsers takes 1000 at a time and reports per-account failures rather
// than throwing the whole batch away.
for (let i = 0; i < doomed.length; i += 1000) {
  const batch = doomed.slice(i, i + 1000).map((u) => u.uid);
  const result = await auth.deleteUsers(batch);
  console.log(`\ndeleted ${result.successCount}, failed ${result.failureCount}`);
  for (const error of result.errors) {
    console.error(`  ${batch[error.index]}: ${error.error.message}`);
  }
}

if (alsoUserDocs) {
  let removed = 0;
  for (const user of doomed) {
    const ref = db.collection('users').doc(user.uid);
    if ((await ref.get()).exists) {
      await db.recursiveDelete(ref);
      removed++;
    }
  }
  console.log(`\nAlso deleted ${removed} users/{uid} documents and their subcollections.`);
}
