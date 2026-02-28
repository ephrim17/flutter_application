import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/bible_swipe_verse_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class SwipeVerseRepository extends ChurchScopedRepository {
  SwipeVerseRepository({
    required super.firestore,
    required super.churchId,
  });

  Future<List<BibleSwipeVerseModel>> fetchVerseRefs() async {
    final doc = await FirestorePaths
        .churchBibleRandomSwipeDoc(firestore, churchId)
        .get();

    final raw = (doc.data())?['verses'] ?? [];

    return (raw as List<dynamic>)
        .map((e) => BibleSwipeVerseModel.fromString(e as String))
        .toList();
  }
}
