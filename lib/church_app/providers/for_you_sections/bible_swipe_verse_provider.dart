import 'package:flutter_application/church_app/services/for_you_section/bible_swipe_repository.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final swipeVersesProvider =
    FutureProvider<List<Map<String, String>>>((ref) async {
  final swipeRepo = SwipeVerseRepository();
  final bibleRepo = BibleRepository();

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

  return verses;
});
