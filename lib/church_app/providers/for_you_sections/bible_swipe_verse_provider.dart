import 'dart:convert';

import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/for_you_section/bible_swipe_repository.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final swipeVersesProvider =
    FutureProvider<List<Map<String, String>>>((ref) async {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) async {
      if (churchId == null) return [];

      final firestore = ref.read(firestoreProvider);

      final swipeRepo = SwipeVerseRepository(
        firestore: firestore,
        churchId: churchId,
      );

      final bibleRepo = BibleRepository();

      // 🔹 Config
      final config = await ref.watch(appConfigProvider.future);
      final enabled = config.bibleSwipeFetchEnabled;
      final remoteVersion = config.bibleSwipeFetchVersion;

      // 🔹 Cache
      final cachedVersion = await getCachedVersion(churchId);
      final cachedData = await loadSwipeCache(churchId);

      final bool canUseCache =
          cachedData != null && cachedVersion == remoteVersion;

      if (!enabled || canUseCache) {
        if (cachedData != null) {
          print("<<<FETCH FROM LOCAL >>>");
          return cachedData;
        }
      }

      print("<<<FETCH FROM FIRESTORE >>>");

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

      if (enabled) {
        await saveSwipeCache(
          churchId: churchId,
          verses: verses,
          version: remoteVersion,
        );
      }

      return verses;
    },
    loading: () async => [],
    error: (_, __) async => [],
  );
});

Future<List<Map<String, String>>?> loadSwipeCache(
    String churchId) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_swipeCacheKey(churchId));
  if (raw == null) return null;

  final decoded = jsonDecode(raw) as List<dynamic>;

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

Future<void> saveSwipeCache({
  required String churchId,
  required List<Map<String, String>> verses,
  required int version,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      _swipeCacheKey(churchId), jsonEncode(verses));
  await prefs.setInt(
      _swipeVersionKey(churchId), version);
}

Future<int?> getCachedVersion(String churchId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_swipeVersionKey(churchId));
}

String _swipeCacheKey(String churchId) =>
    'bible_swipe_cached_verses_$churchId';

String _swipeVersionKey(String churchId) =>
    'bible_swipe_cache_version_$churchId';