class HighlightRef {
  final String book;
  final int chapter;
  final int verse;

  HighlightRef({
    required this.book,
    required this.chapter,
    required this.verse,
  });

  Map<String, dynamic> toJson() => {
        'book': book,
        'chapter': chapter,
        'verse': verse,
      };

  factory HighlightRef.fromJson(Map<String, dynamic> json) {
    return HighlightRef(
      book: json['book'],
      chapter: json['chapter'],
      verse: json['verse'],
    );
  }
}
