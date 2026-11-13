// Security-rules tests against the real firestore.rules, run on the
// Firestore emulator. Rules are the one part of this project with no
// compiler and no analyzer behind them: a mistake here is silent until
// someone is locked out of their own church, or let into someone else's.
//
//   cd tools/rules-tests && npm install
//   JAVA_HOME=... npm test          # Java comes with Android Studio's JBR
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, writeBatch } from 'firebase/firestore';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const RULES = readFileSync(join(here, '../../firestore.rules'), 'utf8');

const SUPER = { uid: 'super-uid', email: 'super@example.com' };
const MEMBER = { uid: 'member-uid', email: 'member@example.com' };
const NEW_ADMIN_UID = 'new-admin-uid';
const CID = 'sample_church';

const testEnv = await initializeTestEnvironment({
  projectId: 'demo-rules',
  firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
});

await testEnv.withSecurityRulesDisabled(async (context) => {
  const db = context.firestore();
  await setDoc(doc(db, 'superAdmins', SUPER.email), { email: SUPER.email, enabled: true });
  await setDoc(doc(db, 'users', SUPER.uid), { name: 'Super', email: SUPER.email });
  await setDoc(doc(db, 'users', MEMBER.uid), { name: 'Member', email: MEMBER.email });
  await setDoc(doc(db, 'users', 'existing-person'), { name: 'Existing', email: 'existing@example.com' });
});

const as = (who) =>
  testEnv.authenticatedContext(who.uid, { email: who.email, email_verified: true }).firestore();

let failures = 0;
async function check(label, expectation, action) {
  let allowed = true;
  try {
    await action();
  } catch (_) {
    allowed = false;
  }
  const ok = allowed === (expectation === 'allow');
  if (!ok) failures++;
  console.log(`${ok ? 'ok  ' : 'FAIL'}  ${label} (expected ${expectation}, got ${allowed ? 'allow' : 'deny'})`);
}

// The church-creation batch. Every document in it is evaluated against
// the state before the batch applies, so config/app does not exist yet
// even though the same batch writes it.
const batch = [
  ['church document', `churches/${CID}`, { name: 'Sample', email: 's@x.com', enabled: true, registrationSource: 'super_admin' }],
  ['config/app', `churches/${CID}/config/app`, { admins: ['newadmin@x.com'], features: {} }],
  ['about', `churches/${CID}/about/main`, { description: '' }],
  ['pastor', `churches/${CID}/pastor/p1`, { title: 'Pastor', primary: true }],
  ['footer contacts', `churches/${CID}/footerSupport/contacts`, { updatedAt: new Date() }],
  ['seeded group', `churches/${CID}/groups/administration`, { name: 'Administration' }],
  ['home section', `churches/${CID}/home_sections/events`, { enabled: true, order: 1 }],
  ['for you section', `churches/${CID}/for_you_section/dailyVerse`, { enabled: true, order: 1 }],
  ['bible swipe verses', `churches/${CID}/bibleRandomSwipeVerses/swipeVerses`, { verses: [] }],
  ['new admin profile', `users/${NEW_ADMIN_UID}`, { name: 'New Admin', email: 'newadmin@x.com' }],
  ['new admin membership', `churches/${CID}/members/${NEW_ADMIN_UID}`, { uid: NEW_ADMIN_UID, role: 'admin', approved: true }],
  ['new admin group row', `churches/${CID}/groups/administration/groupMembers/${NEW_ADMIN_UID}`, { uid: NEW_ADMIN_UID }],
];

console.log('A super admin can write every document the church bootstrap needs:');
// Per document, so a failure names the document rather than "the batch" —
// which is how the users/{adminUid} denial was found.
for (const [label, path, data] of batch) {
  await check(label, 'allow', () => setDoc(doc(as(SUPER), path), data));
}
// The same set again as one batch, against a church that does not exist
// yet — the sequential pass above has already created every document of
// the first one, and re-writing them would be testing `update` rules.
await check('the whole bootstrap, in one batch', 'allow', async () => {
  const db = as(SUPER);
  const writes = writeBatch(db);
  for (const [, path, data] of batch) {
    writes.set(
      doc(db, path.replace(CID, 'sample_church_batched')
        .replace(NEW_ADMIN_UID, 'new-admin-uid-batched')),
      data,
    );
  }
  await writes.commit();
});

// A member of the public registering their own church: they are neither
// a church admin nor a super admin, and the church does not exist yet, so
// canBootstrapChurch is the only thing that can let this through.
console.log('\nA member of the public can register their own church:');
const PUB = 'public_church';
const publicBatch = [
  ['church document, pending and disabled', `churches/${PUB}`,
    { name: 'Theirs', email: 't@x.com', enabled: false, registrationSource: 'public',
      registeredByUid: MEMBER.uid, registeredByEmail: MEMBER.email, approvalStatus: 'pending' }],
  ['config/app', `churches/${PUB}/config/app`, { admins: [MEMBER.email], features: {} }],
  ['about', `churches/${PUB}/about/main`, { description: '' }],
  ['pastor', `churches/${PUB}/pastor/p1`, { title: 'Pastor', primary: true }],
  ['seeded group', `churches/${PUB}/groups/administration`, { name: 'Administration' }],
  // No users/{uid} and no membership row: public registration passes
  // setupChurchAccount: false, so createChurch writes neither. The
  // registrant becomes an admin through config/app.admins instead.
];
// As ONE batch, which is what the client sends. Every write in a batch is
// evaluated against the state *before* the batch applies, so config/app
// does not exist yet for any of them — canBootstrapChurch is what carries
// the whole set. Written one at a time this fails from the second write
// on, because by then the church exists and the registrant is not staff
// yet: a sequential test of this path tests something the app never does.
await check('the whole bootstrap, in one batch', 'allow', async () => {
  const db = as(MEMBER);
  const batch = writeBatch(db);
  for (const [, path, data] of publicBatch) batch.set(doc(db, path), data);
  await batch.commit();
});
await check(
  'but not already enabled',
  'deny',
  () => setDoc(doc(as(MEMBER), 'churches/sneaky_church'), {
    name: 'Sneaky', email: 's@x.com', enabled: true,
    registrationSource: 'public', registeredByUid: MEMBER.uid,
  }),
);
await check(
  'and not in someone else\'s name',
  'deny',
  () => setDoc(doc(as(MEMBER), 'churches/impostor_church'), {
    name: 'Impostor', email: 'i@x.com', enabled: false,
    registrationSource: 'public', registeredByUid: 'someone-else',
  }),
);

// Approval: the super admin flips enabled and approvalStatus on the
// church, and superAdminDisabled on its config.
console.log('\nA super admin can approve a pending registration:');
// Attempted first, while the church is still pending — after approval the
// same write equals what is already there, and a no-op write proves
// nothing.
await check(
  'the registrant cannot approve their own church',
  'deny',
  () => setDoc(doc(as(MEMBER), `churches/${PUB}`),
    { enabled: true, approvalStatus: 'approved' }, { merge: true }),
);
await check(
  'enable the church and mark it approved',
  'allow',
  () => setDoc(doc(as(SUPER), `churches/${PUB}`),
    { enabled: true, approvalStatus: 'approved', approvedAt: new Date() }, { merge: true }),
);
await check(
  'flip superAdminDisabled on its config',
  'allow',
  () => setDoc(doc(as(SUPER), `churches/${PUB}/config/app`), { superAdminDisabled: false }, { merge: true }),
);
await check(
  'and the registrant cannot quietly disable it again',
  'deny',
  () => setDoc(doc(as(MEMBER), `churches/${PUB}`), { enabled: false }, { merge: true }),
);
await check(
  'but they can still edit their church profile',
  'allow',
  () => setDoc(doc(as(MEMBER), `churches/${PUB}`),
    { name: 'Theirs, renamed', address: 'New address', contact: '9876543210' }, { merge: true }),
);

console.log('\nand that did not open anyone else up:');
await check(
  'an ordinary member cannot create a profile for someone else',
  'deny',
  () => setDoc(doc(as(MEMBER), 'users/somebody-else'), { name: 'X', email: 'x@x.com' }),
);
await check(
  'a super admin cannot overwrite an existing profile',
  'deny',
  () => setDoc(doc(as(SUPER), 'users/existing-person'), { name: 'Renamed', email: 'existing@example.com' }),
);
await check(
  'a super admin cannot read someone else\'s profile',
  'deny',
  () => getDoc(doc(as(SUPER), `users/${MEMBER.uid}`)),
);
await check(
  'an ordinary member cannot create a church',
  'deny',
  () => setDoc(doc(as(MEMBER), 'churches/member_church'), { name: 'Mine', enabled: true, registrationSource: 'super_admin' }),
);

await testEnv.cleanup();
console.log(failures === 0 ? '\nAll rules checks passed.' : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
