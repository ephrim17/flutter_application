import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/favorites_repository.dart';
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

  FavoritesRepository? _repository() {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return null;
    return FavoritesRepository(
      firestore: ref.read(firestoreProvider),
      uid: uid,
    );
  }

  /// Firestore is authoritative (§5.1/Phase 4); SharedPreferences stays the
  /// offline cache. Any key still only in the local cache — from before
  /// this device last synced, or from a moment offline — is merged into
  /// Firestore on every load, so nobody ever loses a highlight.
  Future<List<Map<String, String>>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final localKeys = (prefs.getStringList('all_highlights') ?? []).toSet();

    final repository = _repository();
    var keys = localKeys;
    if (repository != null) {
      final remoteKeys = await repository.fetchKeys();
      final localOnly = localKeys.difference(remoteKeys);
      if (localOnly.isNotEmpty) {
        await repository.mergeKeys(localOnly);
      }
      keys = remoteKeys.union(localOnly);
      await prefs.setStringList('all_highlights', keys.toList());
    }

    final repo = BibleRepository();
    final verses = <Map<String, String>>[];
    for (final key in keys) {
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

  /// Clears the local cache only — Firestore favorites survive a logout or
  /// church switch (§5.1: favorites are person-owned, not session-owned).
  /// Called before a different person might sign in on this device so
  /// their session never starts from someone else's cached highlights.
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

    // 2️⃣ Remove from Firestore
    await _repository()?.removeKey(key);

    // 3️⃣ Remove from chapter highlights
    final chapterKey = 'highlight_${book}_${chapter - 1}';
    final chapterHighlights = prefs.getStringList(chapterKey) ?? [];

    chapterHighlights.removeWhere(
      (value) => int.tryParse(value) == verseNumber - 1,
    );

    await prefs.setStringList(chapterKey, chapterHighlights);

    // 4️⃣ Refresh state
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

/// Toggles a verse's favorite state. Writes through to both the local
/// cache and Firestore (§5.1/Phase 4) — pass the signed-in person's
/// [firestore]/[uid] so the Firestore side stays in sync; when [uid] is
/// null (should not normally happen post-signup) this falls back to a
/// local-only toggle, same as before Phase 4.
Future<void> toggleGlobalHighlight(
  String bookKey,
  int chapter,
  int verse, {
  required FirebaseFirestore firestore,
  required String? uid,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getStringList('all_highlights') ?? [];
  final key = "${bookKey}_${chapter}_$verse";
  final wasFavorite = stored.contains(key);
  if (wasFavorite) {
    stored.remove(key);
  } else {
    stored.add(key);
  }
  await prefs.setStringList('all_highlights', stored);

  if (uid == null) return;
  final repository = FavoritesRepository(firestore: firestore, uid: uid);
  if (wasFavorite) {
    await repository.removeKey(key);
  } else {
    await repository.addKey(key);
  }
}
