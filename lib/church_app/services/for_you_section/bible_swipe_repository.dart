import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/bible_swipe_verse_model.dart';

class SwipeVerseRepository {
  final _db = FirebaseFirestore.instance;

  Future<List<BibleSwipeVerseModel>> fetchVerseRefs() async {
    final doc = await _db
        .collection('bibleRandomSwipeVerses')
        .doc('swipeVerses')
        .get();

    final List<dynamic> raw = doc.data()?['verses'] ?? [];

    return raw
        .map((e) => BibleSwipeVerseModel.fromString(e as String))
        .toList();
  }
}
