// Read-only on the server, writes locally. Dumps every Firestore document
// and every Storage object to a folder, so the purge that follows is
// recoverable. Run this before anything destructive — purge.mjs refuses to
// run without the manifest it writes.
//
//   GOOGLE_APPLICATION_CREDENTIALS=/path/key.json \
//   NODE_PATH=../../functions/node_modules node backup.mjs --out ~/church-tree-backup

import { mkdirSync, writeFileSync, createWriteStream } from 'node:fs';
import { dirname, join } from 'node:path';
import { admin, parseArgs, walkDocuments, listAllAuthUsers, bytes } from './_lib.mjs';

const args = parseArgs(process.argv);
const root = args.out || `./backup-${new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-')}`;
const { db, auth, bucket } = admin();

mkdirSync(join(root, 'firestore'), { recursive: true });
mkdirSync(join(root, 'storage'), { recursive: true });

console.log(`Backing up to ${root}\n`);

// Firestore — one JSON file per document, at its own path, so a restore is
// a plain walk of the folder.
let documents = 0;
const writeDoc = async (ref, data) => {
  const file = join(root, 'firestore', `${ref.path}.json`);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, JSON.stringify(data, null, 2));
  documents++;
  if (documents % 250 === 0) console.log(`  ${documents} documents…`);
};

for (const collection of await db.listCollections()) {
  const snapshot = await collection.get();
  for (const doc of snapshot.docs) {
    await writeDoc(doc.ref, doc.data());
    await walkDocuments(doc.ref, writeDoc);
  }
}
console.log(`Firestore: ${documents} documents\n`);

// Auth — exported as JSON. Password hashes are not included by the Admin
// SDK listing, so these records restore the accounts, not their passwords.
const users = await listAllAuthUsers(auth);
writeFileSync(join(root, 'auth-users.json'), JSON.stringify(users.map((u) => u.toJSON()), null, 2));
console.log(`Auth: ${users.length} accounts\n`);

// Storage — every object, at its own path.
const [files] = await bucket.getFiles();
let copied = 0;
let size = 0;
for (const file of files) {
  // The console creates zero-byte objects whose names end in "/" to show a
  // folder. They are not files and cannot be written as one.
  if (file.name.endsWith('/')) continue;
  const destination = join(root, 'storage', file.name);
  mkdirSync(dirname(destination), { recursive: true });
  await new Promise((resolve, reject) => {
    file.createReadStream()
      .on('error', reject)
      .pipe(createWriteStream(destination))
      .on('error', reject)
      .on('finish', resolve);
  });
  copied++;
  size += Number(file.metadata?.size || 0);
  if (copied % 50 === 0) console.log(`  ${copied}/${files.length} objects…`);
}
console.log(`Storage: ${copied} objects, ${bytes(size)}\n`);

writeFileSync(
  join(root, 'manifest.json'),
  JSON.stringify({ takenAt: new Date().toISOString(), documents, authAccounts: users.length, storageObjects: copied, storageBytes: size }, null, 2),
);
console.log(`Done. Manifest at ${join(root, 'manifest.json')}`);
