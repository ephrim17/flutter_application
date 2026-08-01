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
    final parsed = tryParse(ref);
    if (parsed == null) {
      throw FormatException('Invalid Bible verse reference', ref);
    }
    return parsed;
  }

  static BibleSwipeVerseModel? tryParse(String ref) {
    final parts = ref.split(' ');
    if (parts.length < 2) return null;
    final book = parts.sublist(0, parts.length - 1).join(' ');
    final cv = parts.last.split(':');
    if (book.trim().isEmpty || cv.length != 2) return null;
    final chapter = int.tryParse(cv[0]);
    final verse = int.tryParse(cv[1]);
    if (chapter == null || chapter < 1 || verse == null || verse < 1) {
      return null;
    }

    return BibleSwipeVerseModel(
      book: book,
      chapter: chapter,
      verse: verse,
    );
  }
}
