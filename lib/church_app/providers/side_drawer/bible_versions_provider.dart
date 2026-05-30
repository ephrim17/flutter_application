import 'package:flutter_application/church_app/models/bible_version_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_versions_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final bibleVersionsProvider = StreamProvider<List<BibleVersion>>((ref) {
  final repository = BibleVersionsRepository(
    firestore: ref.read(firestoreProvider),
  );

  return repository.watchAvailableVersions();
});
