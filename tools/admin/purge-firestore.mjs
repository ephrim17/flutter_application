// Destructive. Deletes every church except the one named by --keep, and
// the Storage objects filed under those churches.
//
// Dry run by default: it prints exactly what it would remove and stops.
// Removing anything needs `--apply` *and* `--confirm <keepChurchId>`, and
// a backup manifest in --backup, so the irreversible version of this
// command cannot be reached by one stray up-arrow.
//
//   NODE_PATH=../../functions/node_modules GOOGLE_APPLICATION_CREDENTIALS=/path/key.json \
//   node purge-firestore.mjs --keep tnbm --backup ~/church-tree-backup \
//     --apply --confirm tnbm

import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { admin, parseArgs, bytes } from './_lib.mjs';

const args = parseArgs(process.argv);
const keep = args.keep;
const backup = process.argv.includes('--backup')
  ? process.argv[process.argv.indexOf('--backup') + 1]
  : null;

if (!keep) {
  console.error('Give --keep <churchId>: the one church that survives.');
  process.exit(1);
}

const { db, bucket } = admin();

const keepDoc = await db.collection('churches').doc(keep).get();
if (!keepDoc.exists) {
  console.error(`No church "${keep}" — refusing to delete every church in the project.`);
  process.exit(1);
}
console.log(`Keeping ${keep} — "${keepDoc.data()?.name ?? '(unnamed)'}"\n`);

const churches = await db.collection('churches').get();
const doomed = churches.docs.filter((doc) => doc.id !== keep);

console.log('Churches to delete:\n');
for (const church of doomed) {
  console.log(`  ${church.id.padEnd(28)} "${church.data()?.name ?? '(unnamed)'}"`);
}
if (doomed.length === 0) console.log('  (none)');

// Storage is filed as churches/{churchId}/..., with the global feed images
// under churches/global — which belongs to no church and is left alone.
const [allFiles] = await bucket.getFiles({ prefix: 'churches/' });
const doomedIds = new Set(doomed.map((d) => d.id));
const doomedFiles = allFiles.filter((file) => doomedIds.has(file.name.split('/')[1]));
const doomedBytes = doomedFiles.reduce((sum, f) => sum + Number(f.metadata?.size || 0), 0);

console.log(`\nStorage objects to delete: ${doomedFiles.length} (${bytes(doomedBytes)})`);
for (const file of doomedFiles.slice(0, 15)) console.log(`  ${file.name}`);
if (doomedFiles.length > 15) console.log(`  … and ${doomedFiles.length - 15} more`);

if (!args.apply) {
  console.log('\nDry run. Nothing was deleted. Add --apply --confirm <keepChurchId> to go ahead.');
  process.exit(0);
}

if (args.confirm !== keep) {
  console.error(`\n--confirm must repeat the church being kept ("${keep}").`);
  process.exit(1);
}

if (!backup || !existsSync(join(backup, 'manifest.json'))) {
  console.error(`\nNo backup manifest at ${backup ? join(backup, 'manifest.json') : '(--backup not given)'}.`);
  console.error('Run backup.mjs first — this cannot be undone.');
  process.exit(1);
}

console.log('\nDeleting.\n');
for (const church of doomed) {
  // recursiveDelete walks every subcollection; a plain delete would leave
  // the subcollections behind as orphans with no parent document.
  await db.recursiveDelete(church.ref);
  console.log(`  deleted churches/${church.id}`);
}

let removed = 0;
for (const file of doomedFiles) {
  await file.delete();
  removed++;
  if (removed % 25 === 0) console.log(`  ${removed}/${doomedFiles.length} objects…`);
}
console.log(`\nDone: ${doomed.length} churches, ${removed} storage objects.`);
