import * as admin from "firebase-admin";
import {getFirestore} from "firebase-admin/firestore";
import {defineString} from "firebase-functions/params";

/**
 * Which Firestore database the migration-related functions operate on.
 * Defaults to production-safe `(default)`. Set `FIRESTORE_DATABASE_ID` in
 * `functions/.env.<project-id>` to `migrationv1` while testing the
 * user/church decoupling migration (KT Files/architecture/
 * user-church-decoupling-migration.md), then remove it (or reset to
 * `(default)`) before any production deploy — mirrors the Flutter client's
 * own `FIRESTORE_DATABASE_ID` build-time override
 * (`firestore_provider.dart`). Deliberately scoped to only the functions
 * this migration touches, not every trigger in the codebase — see the
 * migration doc's Phase 5/6/7 addenda for exactly which ones.
 */
export const firestoreDatabaseIdParam = defineString("FIRESTORE_DATABASE_ID", {
  default: "(default)",
});

let cached: {id: string; instance: admin.firestore.Firestore} | null = null;

/**
 * Returns the Firestore instance for the configured database, cached per
 * database id (a warm function instance may serve multiple invocations).
 * @return {admin.firestore.Firestore} The Firestore instance to use.
 */
export function firestoreDb(): admin.firestore.Firestore {
  const id = firestoreDatabaseIdParam.value() || "(default)";
  if (cached?.id === id) return cached.instance;
  const instance = id === "(default)" ?
    admin.firestore() :
    getFirestore(admin.app(), id);
  cached = {id, instance};
  return instance;
}
