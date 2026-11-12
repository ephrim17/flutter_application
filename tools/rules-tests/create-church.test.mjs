// Security-rules tests against the real firestore.rules, run on the
// Firestore emulator. Rules are the one part of this project with no
// compiler and no analyzer behind them: a mistake here is silent until
// someone is locked out of their own church, or let into someone else's.
//
//   cd tools/rules-tests && npm install
//   JAVA_HOME=... npm test          # Java comes with Android Studio's JBR
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
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
for (const [label, path, data] of batch) {
  await check(label, 'allow', () => setDoc(doc(as(SUPER), path), data));
}

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
