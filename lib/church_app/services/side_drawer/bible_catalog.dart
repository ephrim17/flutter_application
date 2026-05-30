import 'package:flutter_application/church_app/models/bible_book_model.dart';
import 'package:flutter_application/church_app/models/bible_version_model.dart';

final bibleBooks = [
  BibleBook(key: 'Genesis', name: 'ஆதியாகமம்'),
  BibleBook(key: 'Exodus', name: 'யாத்திராகமம்'),
  BibleBook(key: 'Leviticus', name: 'லேவியராகமம்'),
  BibleBook(key: 'Numbers', name: 'எண்ணாகமம்'),
  BibleBook(key: 'Deuteronomy', name: 'உபாகமம்'),
  BibleBook(key: 'Joshua', name: 'யோசுவா'),
  BibleBook(key: 'Judges', name: 'நியாயாதிபதிகள்'),
  BibleBook(key: 'Ruth', name: 'ரூத்'),
  BibleBook(key: '1 Samuel', name: '1 சாமுவேல்'),
  BibleBook(key: '2 Samuel', name: '2 சாமுவேல்'),
  BibleBook(key: '1 Kings', name: '1 இராஜாக்கள்'),
  BibleBook(key: '2 Kings', name: '2 இராஜாக்கள்'),
  BibleBook(key: '1 Chronicles', name: '1 நாளாகமம்'),
  BibleBook(key: '2 Chronicles', name: '2 நாளாகமம்'),
  BibleBook(key: 'Ezra', name: 'எஸ்றா'),
  BibleBook(key: 'Nehemiah', name: 'நெகேமியா'),
  BibleBook(key: 'Esther', name: 'எஸ்தர்'),
  BibleBook(key: 'Job', name: 'யோபு'),
  BibleBook(key: 'Psalms', name: 'சங்கீதம்'),
  BibleBook(key: 'Proverbs', name: 'நீதிமொழிகள்'),
  BibleBook(key: 'Ecclesiastes', name: 'பிரசங்கி'),
  BibleBook(key: 'SongOfSolomon', name: 'உன்னதப்பாட்டு'),
  BibleBook(key: 'Isaiah', name: 'ஏசாயா'),
  BibleBook(key: 'Jeremiah', name: 'எரேமியா'),
  BibleBook(key: 'Lamentations', name: 'புலம்பல்'),
  BibleBook(key: 'Ezekiel', name: 'எசேக்கியேல்'),
  BibleBook(key: 'Daniel', name: 'தானியேல்'),
  BibleBook(key: 'Hosea', name: 'ஓசியா'),
  BibleBook(key: 'Joel', name: 'யோவேல்'),
  BibleBook(key: 'Amos', name: 'ஆமோஸ்'),
  BibleBook(key: 'Obadiah', name: 'ஒபதியா'),
  BibleBook(key: 'Jonah', name: 'யோனா'),
  BibleBook(key: 'Micah', name: 'மீகா'),
  BibleBook(key: 'Nahum', name: 'நாகூம்'),
  BibleBook(key: 'Habakkuk', name: 'ஆபகூக்'),
  BibleBook(key: 'Zephaniah', name: 'செப்பனியா'),
  BibleBook(key: 'Haggai', name: 'ஆகாய்'),
  BibleBook(key: 'Zechariah', name: 'சகரியா'),
  BibleBook(key: 'Malachi', name: 'மல்கியா'),
  BibleBook(key: 'Matthew', name: 'மத்தேயு'),
  BibleBook(key: 'Mark', name: 'மாற்கு'),
  BibleBook(key: 'Luke', name: 'லூக்கா'),
  BibleBook(key: 'John', name: 'யோவான்'),
  BibleBook(key: 'Acts', name: 'அப்போஸ்தலர் நடபடிகள்'),
  BibleBook(key: 'Romans', name: 'ரோமர்'),
  BibleBook(key: '1 Corinthians', name: '1 கொரிந்தியர்'),
  BibleBook(key: '2 Corinthians', name: '2 கொரிந்தியர்'),
  BibleBook(key: 'Galatians', name: 'கலாத்தியர்'),
  BibleBook(key: 'Ephesians', name: 'எபேசியர்'),
  BibleBook(key: 'Philippians', name: 'பிலிப்பியர்'),
  BibleBook(key: 'Colossians', name: 'கொலோசெயர்'),
  BibleBook(key: '1 Thessalonians', name: '1 தெசலோனிக்கேயர்'),
  BibleBook(key: '2 Thessalonians', name: '2 தெசலோனிக்கேயர்'),
  BibleBook(key: '1 Timothy', name: '1 தீமோத்தேயு'),
  BibleBook(key: '2 Timothy', name: '2 தீமோத்தேயு'),
  BibleBook(key: 'Titus', name: 'தீத்து'),
  BibleBook(key: 'Philemon', name: 'பிலேமோன்'),
  BibleBook(key: 'Hebrews', name: 'எபிரேயர்'),
  BibleBook(key: 'James', name: 'யாக்கோபு'),
  BibleBook(key: '1 Peter', name: '1 பேதுரு'),
  BibleBook(key: '2 Peter', name: '2 பேதுரு'),
  BibleBook(key: '1 John', name: '1 யோவான்'),
  BibleBook(key: '2 John', name: '2 யோவான்'),
  BibleBook(key: '3 John', name: '3 யோவான்'),
  BibleBook(key: 'Jude', name: 'யூதா'),
  BibleBook(key: 'Revelation', name: 'வெளிப்படுத்தின விசேஷம்'),
];

final bibleBookFileNames =
    bibleBooks.map((book) => '${book.key}.json').toList(growable: false);

final fallbackBibleVersions = [
  BibleVersion(
    id: 'english_tamil',
    title: 'English & Tamil Bible',
    subtitle: 'KJV English with Tamil parallel text',
    languageLabel: 'EN + TA',
    description: 'Downloads all 66 book files for offline reading.',
    bookFileNames: bibleBookFileNames,
    storagePath: 'bible/english_tamil',
    contentVersion: 1,
  ),
];

BibleVersion defaultBibleVersion = fallbackBibleVersions.first;

BibleVersion bibleVersionById(String? id) {
  return fallbackBibleVersions.firstWhere(
    (version) => version.id == id,
    orElse: () => defaultBibleVersion,
  );
}
