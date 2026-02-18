import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/bible_swipe_verse_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class SwipeVerseRepository {
  final _db = FirebaseFirestore.instance;

  Future<List<BibleSwipeVerseModel>> fetchVerseRefs() async {
    final doc = await FirestorePaths
        .bibleRandomSwipeDoc(_db)
        .get();

    final List<dynamic> raw = (doc.data() as Map<String, dynamic>?)?['verses'] ?? [];

    return raw
        .map((e) => BibleSwipeVerseModel.fromString(e as String))
        .toList();
  }
}
