import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<Map<String, String>>>(
        FavoritesNotifier.new);

class FavoritesNotifier
    extends AsyncNotifier<List<Map<String, String>>> {

  @override
  Future<List<Map<String, String>>> build() async {
    return loadFavorites();
  }

  Future<List<Map<String, String>>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('all_highlights') ?? [];

    final repo = BibleRepository();
    List<Map<String, String>> verses = [];

    for (var key in stored) {
      final parts = key.split('_');

      final book = parts[0];
      final chapter = int.parse(parts[1]);
      final verse = int.parse(parts[2]);

      final verseData = await repo.getVerse(
        book: book,
        chapter: chapter,
        verse: verse,
      );

      verses.add(verseData);
    }

    return verses;
  }

  /// 🔥 REMOVE highlight here
  Future<void> removeHighlight(Map<String, String> verse) async {
    final prefs = await SharedPreferences.getInstance();

    final reference = verse['reference'] ?? '';
    final parts = reference.split(' ');

    final book = parts.first;
    final chapterVerse = parts.last.split(':');

    final chapter = int.parse(chapterVerse[0]);
    final verseNumber = int.parse(chapterVerse[1]);

    final key = "${book}_${chapter}_${verseNumber}";

    // 1️⃣ Remove from global highlights
    final global = prefs.getStringList('all_highlights') ?? [];
    global.remove(key);
    await prefs.setStringList('all_highlights', global);

    // 2️⃣ Remove from chapter highlights
    final chapterKey = 'highlight_${book}_${chapter - 1}';
    final chapterHighlights = prefs.getStringList(chapterKey) ?? [];

    chapterHighlights.removeWhere(
        (v) => int.parse(v) == verseNumber - 1);

    await prefs.setStringList(chapterKey, chapterHighlights);

    // 3️⃣ Refresh state
    state = const AsyncLoading();
    state = AsyncData(await loadFavorites());
  }
}

/// Highlight helpers for use in VerseScreen and elsewhere
Future<Set<int>> loadHighlights(String bookKey, int actualChapterIndex) async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getStringList('highlight_${bookKey}_$actualChapterIndex');
  return (stored?.map(int.parse).toSet() ?? <int>{});
}

Future<void> saveHighlights(String bookKey, int actualChapterIndex, Set<int> highlightedVerses) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(
    'highlight_${bookKey}_$actualChapterIndex',
    highlightedVerses.map((e) => e.toString()).toList(),
  );
}

Future<void> toggleGlobalHighlight(String bookKey, int chapter, int verse) async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getStringList('all_highlights') ?? [];
  final key = "${bookKey}_${chapter}_${verse}";
  if (stored.contains(key)) {
    stored.remove(key);
  } else {
    stored.add(key);
  }
  await prefs.setStringList('all_highlights', stored);
}
