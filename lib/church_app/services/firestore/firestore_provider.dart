import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firestore's default database id — every environment has this one.
/// Compared against [firestoreDatabaseId] to detect a non-production build.
const String defaultFirestoreDatabaseId = '(default)';

/// Database id override, set at build/test time via
/// `--dart-define=FIRESTORE_DATABASE_ID=migrationv1`. Empty means
/// "use production". This is the only place in the app allowed to read it —
/// see KT Files/architecture/user-church-decoupling-migration.md §3.
const String _firestoreDatabaseIdOverride =
    String.fromEnvironment('FIRESTORE_DATABASE_ID');

/// The database this build actually targets. [defaultFirestoreDatabaseId]
/// unless overridden. Logged once at startup in main.dart and surfaced by
/// `DatabaseOverrideDebugBanner` so a forgotten `--dart-define` fails loudly
/// instead of silently testing against production.
final String firestoreDatabaseId = _firestoreDatabaseIdOverride.isEmpty
    ? defaultFirestoreDatabaseId
    : _firestoreDatabaseIdOverride;

/// The single Firestore instance for the whole app. Every read/write must go
/// through this provider — see
/// KT Files/architecture/user-church-decoupling-migration.md §3 for why a
/// second entry point risks silently corrupting production data during the
/// user/church decoupling migration. A caller that reaches for the SDK's
/// default-instance accessor directly bypasses the database selector above.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  if (firestoreDatabaseId == defaultFirestoreDatabaseId) {
    return FirebaseFirestore.instance;
  }
  return FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: firestoreDatabaseId,
  );
});
