import 'package:flutter_application/church_app/providers/for_you_sections/bible_verse_provider.dart';

class BibleFontConfig {
  static double verseNumber(BibleFontSize size) {
    switch (size) {
      case BibleFontSize.small:
        return 12;
      case BibleFontSize.medium:
        return 14;
      case BibleFontSize.large:
        return 16;
    }
  }

  static double tamil(BibleFontSize size) {
    switch (size) {
      case BibleFontSize.small:
        return 14;
      case BibleFontSize.medium:
        return 16;
      case BibleFontSize.large:
        return 18;
    }
  }

  static double english(BibleFontSize size) {
    switch (size) {
      case BibleFontSize.small:
        return 13;
      case BibleFontSize.medium:
        return 14;
      case BibleFontSize.large:
        return 16;
    }
  }
}
