import 'dart:convert';

class FavoriteVerse {
  final String english;
  final String tamil;
  final String reference;

  FavoriteVerse({
    required this.english,
    required this.tamil,
    required this.reference,
  });

  Map<String, dynamic> toMap() => {
        'english': english,
        'tamil': tamil,
        'reference': reference,
      };

  factory FavoriteVerse.fromMap(Map<String, dynamic> map) {
    return FavoriteVerse(
      english: map['english'],
      tamil: map['tamil'],
      reference: map['reference'],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory FavoriteVerse.fromJson(String json) =>
      FavoriteVerse.fromMap(jsonDecode(json));
}
