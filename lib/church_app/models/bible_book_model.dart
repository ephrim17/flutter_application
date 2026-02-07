class BibleBook {
  final String key;   // Genesis
  final String name;  // ஆதியாகமம்

  BibleBook({required this.key, required this.name});
}

class BibleVerseModel {
  final int verse;
  final String tamil;
  final String english;

  BibleVerseModel({
    required this.verse,
    required this.tamil,
    required this.english,
  });
}
