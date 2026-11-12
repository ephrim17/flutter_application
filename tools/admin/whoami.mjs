// Read-only: what the security rules will see for an account.
import { admin } from './_lib.mjs';
const { db, auth } = admin();
const email = process.argv[process.argv.indexOf('--email') + 1];
const user = await auth.getUserByEmail(email);
console.log('auth uid           :', user.uid);
console.log('auth emailVerified :', user.emailVerified);
console.log('auth disabled      :', user.disabled);
const doc = await db.collection('users').doc(user.uid).get();
console.log('users/{uid} exists :', doc.exists);
if (doc.exists) {
  const d = doc.data() || {};
  console.log('  emailVerified    :', d.emailVerified, '(rules default when absent: true)');
  console.log('  fields           :', Object.keys(d).join(', '));
}
const sa = await db.collection('superAdmins').doc(email.toLowerCase()).get();
console.log('superAdmins/{email}:', sa.exists, sa.exists ? JSON.stringify(sa.data()) : '');
