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
      id: (json['id'] as num?)?.toInt() ?? 0,
      theme: json['theme']?.toString().trim() ?? '',
      reference: json['reference']?.toString().trim() ?? '',
      english: json['english']?.toString() ?? '',
      tamil: json['tamil']?.toString() ?? '',
    );
  }
}
