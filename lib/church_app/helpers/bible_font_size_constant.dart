import 'package:hooks_riverpod/legacy.dart';

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
        return 16;
      case BibleFontSize.medium:
        return 18;
      case BibleFontSize.large:
        return 20;
    }
  }

  static double english(BibleFontSize size) {
    switch (size) {
      case BibleFontSize.small:
        return 16;
      case BibleFontSize.medium:
        return 18;
      case BibleFontSize.large:
        return 20;
    }
  }
}

enum BibleFontSize {
  small,
  medium,
  large,
}

final bibleFontSizeProvider =
    StateProvider<BibleFontSize>((ref) => BibleFontSize.medium);