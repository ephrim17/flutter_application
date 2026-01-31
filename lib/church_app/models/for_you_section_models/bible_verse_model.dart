class BibleVerse {
  final int id;
  final String theme;
  final String reference;
  final String english;
  final String tamil;

  BibleVerse({
    required this.id,
    required this.theme,
    required this.reference,
    required this.english,
    required this.tamil,
  });

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(
      id: json['id'] as int,
      theme: json['theme'] as String,
      reference: json['reference'] as String,
      english: json['english'] as String,
      tamil: json['tamil'] as String,
    );
  }
}
