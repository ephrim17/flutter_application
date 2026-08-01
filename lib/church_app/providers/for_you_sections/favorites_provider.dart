import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<Map<String, String>>>(
        FavoritesNotifier.new);

class FavoritesNotifier extends AsyncNotifier<List<Map<String, String>>> {
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
      if (parts.length < 3) continue;

      final book = parts.sublist(0, parts.length - 2).join('_');
      final chapter = int.tryParse(parts[parts.length - 2]);
      final verse = int.tryParse(parts.last);
      if (book.isEmpty || chapter == null || verse == null) continue;

      final verseData = await repo.getVerse(
        book: book,
        chapter: chapter,
        verse: verse,
      );

      verses.add(verseData);
    }

    return verses;
  }

  /// 🔥 NEW METHOD
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('all_highlights');

    state = const AsyncData([]);
  }

  /// 🔥 REMOVE highlight here
  Future<void> removeHighlight(Map<String, String> verse) async {
    final prefs = await SharedPreferences.getInstance();

    final reference = verse['reference'] ?? '';
    final parts = reference.split(' ');
    if (parts.length < 2) return;

    final book = parts.sublist(0, parts.length - 1).join(' ');
    final chapterVerse = parts.last.split(':');
    if (chapterVerse.length != 2) return;

    final chapter = int.tryParse(chapterVerse[0]);
    final verseNumber = int.tryParse(chapterVerse[1]);
    if (chapter == null || verseNumber == null) return;

    final key = "${book}_${chapter}_$verseNumber";

    // 1️⃣ Remove from global highlights
    final global = prefs.getStringList('all_highlights') ?? [];
    global.remove(key);
    await prefs.setStringList('all_highlights', global);

    // 2️⃣ Remove from chapter highlights
    final chapterKey = 'highlight_${book}_${chapter - 1}';
    final chapterHighlights = prefs.getStringList(chapterKey) ?? [];

    chapterHighlights.removeWhere(
      (value) => int.tryParse(value) == verseNumber - 1,
    );

    await prefs.setStringList(chapterKey, chapterHighlights);

    // 3️⃣ Refresh state
    state = const AsyncLoading();
    state = AsyncData(await loadFavorites());
  }
}

/// Highlight helpers for use in VerseScreen and elsewhere
Future<Set<int>> loadHighlights(String bookKey, int actualChapterIndex) async {
  final prefs = await SharedPreferences.getInstance();
  final stored =
      prefs.getStringList('highlight_${bookKey}_$actualChapterIndex');
  return stored?.map(int.tryParse).whereType<int>().toSet() ?? <int>{};
}

Future<void> saveHighlights(
    String bookKey, int actualChapterIndex, Set<int> highlightedVerses) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(
    'highlight_${bookKey}_$actualChapterIndex',
    highlightedVerses.map((e) => e.toString()).toList(),
  );
}

Future<void> toggleGlobalHighlight(
    String bookKey, int chapter, int verse) async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getStringList('all_highlights') ?? [];
  final key = "${bookKey}_${chapter}_$verse";
  if (stored.contains(key)) {
    stored.remove(key);
  } else {
    stored.add(key);
  }
  await prefs.setStringList('all_highlights', stored);
}
