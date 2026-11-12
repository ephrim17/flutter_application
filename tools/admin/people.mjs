// Read-only. Who is still recorded in the project, and which of those
// records belong to an account that still exists.
//
//   node tools/admin/people.mjs --key /path/key.json --church tnbm

import { admin, listAllAuthUsers } from './_lib.mjs';

const argv = process.argv;
const church = argv.includes('--church') ? argv[argv.indexOf('--church') + 1] : 'tnbm';
const { db, auth } = admin();

const accounts = await listAllAuthUsers(auth);
const liveUids = new Set(accounts.map((u) => u.uid));
console.log(`Auth accounts (${accounts.length}):`);
for (const user of accounts) console.log(`  ${user.email}  ${user.uid}`);

const churchRef = db.collection('churches').doc(church);

for (const name of ['members', 'memberDirectory']) {
  const snapshot = await churchRef.collection(name).get();
  console.log(`\nchurches/${church}/${name} (${snapshot.size}):`);
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const uid = data.uid || data.userId || doc.id;
    const live = liveUids.has(uid) || liveUids.has(doc.id);
    console.log(
      `  ${live ? 'KEEP' : 'orphan'}  ${(data.displayName || data.name || '(no name)').padEnd(26)} ${doc.id}`,
    );
  }
}

const families = await churchRef.collection('families').get();
console.log(`\nchurches/${church}/families (${families.size}):`);
for (const doc of families.docs) {
  const data = doc.data() || {};
  const members = data.memberIds || data.members || [];
  console.log(`  ${(data.name || data.familyName || '(unnamed)').padEnd(26)} ${doc.id}  members:${Array.isArray(members) ? members.length : '?'}`);
}

const users = await db.collection('users').get();
console.log(`\nusers (${users.size}):`);
for (const doc of users.docs) {
  const data = doc.data() || {};
  console.log(
    `  ${liveUids.has(doc.id) ? 'KEEP' : 'orphan'}  ${(data.email || data.name || '(no email)').padEnd(34)} ${doc.id}`,
  );
}
