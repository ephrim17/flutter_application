

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/models/bible_verses_swipes_model.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/bible_verse_model.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class BibleVerseRepository {
  BibleVerseRepository(this.ref);
  final Ref ref;

  // Future<List<BibleVerse>> getRandomVerses() async {
  //   final raw = bibleversejsn;
  //   final verses = raw.map((e) => BibleVerse.fromJson(e)).toList();
  //   verses.shuffle();
  //   return verses;
  // }

  List<BibleVerse> getAllVerses() {
    final List<dynamic> raw = bibleVerseSwipesJson['verses'];

    return raw
        .map((e) => BibleVerse.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

Future<List<dynamic>> loadBibleVersesRaw() async {
  final jsonString =
      await rootBundle.loadString('assets/json/bible_verses.json');

  return json.decode(jsonString) as List<dynamic>;
}