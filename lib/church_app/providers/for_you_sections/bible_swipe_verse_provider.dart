import 'dart:convert';

import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/services/for_you_section/bible_swipe_repository.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final swipeVersesProvider =
    FutureProvider<List<Map<String, String>>>((ref) async {

  final swipeRepo = SwipeVerseRepository();
  final bibleRepo = BibleRepository();

  // 🔹 Config
  final config = await ref.watch(appConfigProvider.future);
  final enabled = config.bibleSwipeFetchEnabled;
  final remoteVersion = config.bibleSwipeFetchVersion;

  // 🔹 Try cache first
  final cachedVersion = await getCachedVersion();
  final cachedData = await loadSwipeCache();

  final bool canUseCache =
      cachedData != null && cachedVersion == remoteVersion;

  // ✅ Use cache when:
  // 1. Fetch disabled OR
  // 2. Version unchanged
  if (!enabled || canUseCache) {
    if (cachedData != null) {
      print("<<<FETCH FROM LOCAL >>>");
      return cachedData;
    }
  }

  print("<<<FETCH FROM FIRESTORE >>>");

  // 🔥 Fetch from Firestore
  final refs = await swipeRepo.fetchVerseRefs();
  final List<Map<String, String>> verses = [];

  for (final r in refs) {
    final verse = await bibleRepo.getVerse(
      book: r.book,
      chapter: r.chapter,
      verse: r.verse,
    );

    verses.add({
      'book': r.book,
      'chapter': r.chapter.toString(),
      'verse': r.verse.toString(),
      'tamil': verse['tamil'] ?? verse['text'] ?? '',
      'english': verse['english'] ?? '',
      'reference': '${r.book} ${r.chapter}:${r.verse}',
    });
  }

  // 💾 Save cache only when fetch enabled
  if (enabled) {
    await saveSwipeCache(verses, remoteVersion);
  }

  return verses;
});

const _swipeCacheKey = 'bible_swipe_cached_verses';
const _swipeVersionKey = 'bible_swipe_cache_version';


Future<List<Map<String, String>>?> loadSwipeCache() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_swipeCacheKey);
  if (raw == null) return null;

  final List<dynamic> decoded = jsonDecode(raw);

  return decoded.map((e) {
    final map = Map<String, dynamic>.from(e);

    return {
      'book': map['book']?.toString() ?? '',
      'chapter': map['chapter']?.toString() ?? '',
      'verse': map['verse']?.toString() ?? '',
      'tamil': map['tamil']?.toString() ?? '',
      'english': map['english']?.toString() ?? '',
      'reference': map['reference']?.toString() ?? '',
    };
  }).toList();
}


Future<void> saveSwipeCache(
  List<Map<String, String>> verses,
  int version,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_swipeCacheKey, jsonEncode(verses));
  await prefs.setInt(_swipeVersionKey, version);
}

Future<int?> getCachedVersion() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_swipeVersionKey);
}
