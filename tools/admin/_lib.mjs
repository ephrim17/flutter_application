// Shared plumbing for the admin scripts.
//
// These run against the live project with a service-account key, outside
// the app and outside the security rules. Everything here is built so that
// the read-only path is the easy one and the destructive path has to be
// asked for twice: `--apply` plus `--confirm <keepChurchId>`.

import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { getStorage } from 'firebase-admin/storage';
import { readFileSync } from 'node:fs';

export const PROJECT_ID = 'flutterlearning-c9f6c';
export const STORAGE_BUCKET = 'flutterlearning-c9f6c.firebasestorage.app';

/** Collections that live at the root rather than under a church. */
export const ROOT_COLLECTIONS = [
  'churches',
  'users',
  'globalFeeds',
  'globalFeedback',
  'mail',
  'bible_versions',
  'learning_modules',
  'learning_progress',
  'learning_results',
  'superAdmins',
  'config',
];

export function parseArgs(argv) {
  const args = { apply: false, confirm: null, keep: null, out: null, flags: new Set() };
  for (let i = 2; i < argv.length; i++) {
    const token = argv[i];
    if (token === '--apply') args.apply = true;
    else if (token === '--confirm') args.confirm = argv[++i];
    else if (token === '--keep') args.keep = argv[++i];
    else if (token === '--out') args.out = argv[++i];
    else if (token.startsWith('--')) args.flags.add(token.slice(2));
  }
  return args;
}

export function admin() {
  if (getApps().length === 0) {
    const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (!keyPath) {
      throw new Error(
        'Set GOOGLE_APPLICATION_CREDENTIALS to the service-account key file.',
      );
    }
    const credential = cert(JSON.parse(readFileSync(keyPath, 'utf8')));
    initializeApp({ credential, projectId: PROJECT_ID, storageBucket: STORAGE_BUCKET });
  }
  return {
    db: getFirestore(),
    auth: getAuth(),
    bucket: getStorage().bucket(),
  };
}

/** Every auth account, paged. */
export async function listAllAuthUsers(auth) {
  const users = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  return users;
}

/**
 * The uids that belong to a church.
 *
 * A membership document is keyed by its own id and also carries the uid in
 * a field, and which field has varied across the user/church decoupling
 * migration — so every candidate is collected rather than trusting one.
 */
export async function churchMemberUids(db, churchId) {
  const uids = new Set();
  const snapshot = await db.collection('churches').doc(churchId).collection('members').get();
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    for (const value of [doc.id, data.uid, data.userId, data.id, data.authUid]) {
      if (typeof value === 'string' && value.trim().length > 20) uids.add(value.trim());
    }
  }
  return uids;
}

/** Walks a document tree, calling `visit(ref, data)` for every document. */
export async function walkDocuments(ref, visit) {
  const collections = await ref.listCollections();
  for (const collection of collections) {
    const snapshot = await collection.get();
    for (const doc of snapshot.docs) {
      await visit(doc.ref, doc.data());
      await walkDocuments(doc.ref, visit);
    }
  }
}

export function bytes(size) {
  const units = ['B', 'KB', 'MB', 'GB'];
  let value = Number(size) || 0;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return `${value.toFixed(value >= 10 || unit === 0 ? 0 : 1)}${units[unit]}`;
}
