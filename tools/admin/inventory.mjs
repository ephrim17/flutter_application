// Read-only. Prints what is actually in the project, so a deletion plan is
// made from the data rather than from assumptions about path names.
//
//   GOOGLE_APPLICATION_CREDENTIALS=/path/key.json \
//   NODE_PATH=../../functions/node_modules node inventory.mjs

import { admin, listAllAuthUsers, churchMemberUids, ROOT_COLLECTIONS, bytes } from './_lib.mjs';

const { db, auth, bucket } = admin();

console.log('# Churches\n');
const churches = await db.collection('churches').get();
const churchRows = [];
for (const church of churches.docs) {
  const data = church.data() || {};
  const subcollections = await church.ref.listCollections();
  let documents = 0;
  const parts = [];
  for (const collection of subcollections) {
    const count = (await collection.count().get()).data().count;
    documents += count;
    if (count > 0) parts.push(`${collection.id}:${count}`);
  }
  churchRows.push({ id: church.id, name: data.name || '(unnamed)', documents });
  console.log(`${church.id}  "${data.name || '(unnamed)'}"`);
  console.log(`  documents in subcollections: ${documents}`);
  console.log(`  ${parts.join('  ') || '(empty)'}\n`);
}

console.log('# Root collections\n');
for (const name of ROOT_COLLECTIONS) {
  if (name === 'churches') continue;
  const count = (await db.collection(name).count().get()).data().count;
  console.log(`${name.padEnd(20)} ${count}`);
}

console.log('\n# Storage, by top-level prefix\n');
const [files] = await bucket.getFiles();
const prefixes = new Map();
for (const file of files) {
  const prefix = file.name.split('/').slice(0, 2).join('/');
  const entry = prefixes.get(prefix) || { count: 0, size: 0 };
  entry.count++;
  entry.size += Number(file.metadata?.size || 0);
  prefixes.set(prefix, entry);
}
for (const [prefix, entry] of [...prefixes].sort((a, b) => b[1].size - a[1].size)) {
  console.log(`${prefix.padEnd(40)} ${String(entry.count).padStart(5)} files  ${bytes(entry.size)}`);
}

console.log('\n# Auth accounts\n');
const keepChurch = process.argv[2];
const users = await listAllAuthUsers(auth);
console.log(`total: ${users.length}`);

if (keepChurch) {
  const memberUids = await churchMemberUids(db, keepChurch);
  const inChurch = users.filter((u) => memberUids.has(u.uid));
  console.log(`members of ${keepChurch}: ${inChurch.length} (of ${memberUids.size} membership docs)`);
  console.log(`not members of ${keepChurch}: ${users.length - inChurch.length}`);
  console.log('\nmembers (kept):');
  for (const user of inChurch) {
    console.log(`  ${(user.email || '(no email)').padEnd(36)} ${user.metadata.lastSignInTime || ''}`);
  }
}
