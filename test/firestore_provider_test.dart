import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Independently re-reads the same dart-define the provider reads, so the
/// expectation below isn't just parroting the provider's own module state.
const _override = String.fromEnvironment('FIRESTORE_DATABASE_ID');

/// firestoreProvider is the single Firestore entry point for the app (KT
/// Files/architecture/user-church-decoupling-migration.md §3) — a caller
/// that bypasses it silently targets production instead of a migration
/// database, with no error. Its database selector is a compile-time
/// `--dart-define`, so this one test exercises both branches depending on
/// how it's invoked:
///
///   flutter test                                              -> default
///   flutter test --dart-define=FIRESTORE_DATABASE_ID=migrationv1 -> override
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  test(
    'firestoreProvider resolves to the database selected by '
    'FIRESTORE_DATABASE_ID (or production when unset)',
    () {
      final expected =
          _override.isEmpty ? defaultFirestoreDatabaseId : _override;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(firestoreProvider).databaseId, expected);
    },
  );
}
