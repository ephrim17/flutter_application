import 'package:flutter/material.dart';

/// Platform colour-emoji fonts, most specific first.
///
/// Naming them explicitly is the whole point: the app's text theme is
/// `GoogleFonts.interTextTheme`, and **Inter ships its own monochrome glyph
/// for U+2764 (❤)**. "❤️" is U+2764 followed by the emoji variation selector,
/// but once Inter claims the base character the selector is ignored and the
/// heart renders as a thin grey outline instead of a red emoji — which is
/// exactly how it looked in the feed's reaction picker. A font that has no
/// text glyphs at all cannot make that mistake.
///
/// A name that does not exist on the running platform is skipped, so the same
/// list is safe everywhere: Android resolves the first, Apple platforms the
/// second, Windows/web the third, and anything unlisted falls through to the
/// system default.
const List<String> emojiFontFamilyFallback = <String>[
  'Noto Color Emoji',
  'Apple Color Emoji',
  'Segoe UI Emoji',
];

/// A text style for rendering emoji, and nothing but emoji.
///
/// Use it anywhere a user-visible emoji is drawn on its own — reaction
/// pickers, reaction chips, the "who reacted" list. Do not use it for text
/// that merely *contains* an emoji, since the surrounding letters would lose
/// the app's typeface.
TextStyle emojiTextStyle({
  required double fontSize,
  Color? color,
  double? height,
}) {
  return TextStyle(
    fontSize: fontSize,
    color: color,
    height: height,
    fontFamily: emojiFontFamilyFallback.first,
    fontFamilyFallback: emojiFontFamilyFallback.sublist(1),
  );
}
