import 'package:flutter_application/church_app/widgets/language_toggle_widget.dart';
import 'package:hooks_riverpod/legacy.dart';

final dailyVerseLanguageProvider =
    StateProvider<BibleLanguage>((ref) => BibleLanguage.tamil);

final chapterReaderLanguageProvider =
    StateProvider<BibleLanguage>((ref) => BibleLanguage.tamil);