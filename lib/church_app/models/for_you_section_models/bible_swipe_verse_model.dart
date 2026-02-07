class BibleSwipeVerseModel {
  final String book;
  final int chapter;
  final int verse;

  BibleSwipeVerseModel({
    required this.book,
    required this.chapter,
    required this.verse,
  });

  factory BibleSwipeVerseModel.fromString(String ref) {
    // Psalms 1:2
    final parts = ref.split(' ');
    final book = parts.sublist(0, parts.length - 1).join(' ');
    final cv = parts.last.split(':');

    return BibleSwipeVerseModel(
      book: book,
      chapter: int.parse(cv[0]),
      verse: int.parse(cv[1]),
    );
  }
}
