import 'dart:math';
import 'package:flutter_application/church_app/models/for_you_section_model/bible_verse_model.dart';
import 'package:flutter_application/church_app/services/for_you_section/bible_verse_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

final allBibleVersesProvider = FutureProvider<List<BibleVerse>>((ref) async {
  final repo = BibleVerseRepository(ref);
  return repo.getAllVerses();
});

final randomBibleVerseProvider =
    StateNotifierProvider<RandomBibleVerseNotifier, BibleVerse?>((ref) {
  final asyncVerses = ref.watch(allBibleVersesProvider);

  return asyncVerses.when(
    data: (verses) => RandomBibleVerseNotifier(verses),
    loading: () => RandomBibleVerseNotifier(const []),
    error: (_, __) => RandomBibleVerseNotifier(const []),
  );
});

class RandomBibleVerseNotifier extends StateNotifier<BibleVerse?> {
  RandomBibleVerseNotifier(this._verses)
      : super(_verses.isEmpty ? null : _randomVerse(_verses));

  final List<BibleVerse> _verses;
  static final _rand = Random();

  static BibleVerse _randomVerse(List<BibleVerse> verses) {
    return verses[_rand.nextInt(verses.length)];
  }

  void next() {
    if (_verses.isEmpty) return;
    state = _randomVerse(_verses);
  }
}
