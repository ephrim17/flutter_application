import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/helpers/emoji_text_style.dart';
import 'package:flutter_application/church_app/models/feed_reaction_model.dart';
import 'package:flutter_application/church_app/widgets/shimmer_image.dart';

void main() {
  group('emojiTextStyle', () {
    // The app theme is GoogleFonts.interTextTheme, and Inter has its own
    // monochrome glyph for U+2764. If an emoji ever resolves to Inter again,
    // "❤️" goes back to rendering as a thin grey heart in the reaction picker.
    test('never resolves to the app text font', () {
      final style = emojiTextStyle(fontSize: 26);
      expect(style.fontFamily, isNot('Inter'));
      expect(style.fontFamily, emojiFontFamilyFallback.first);
      expect(style.fontFamilyFallback, emojiFontFamilyFallback.sublist(1));
    });

    test('covers Android, Apple and Windows emoji fonts', () {
      final families = [
        emojiTextStyle(fontSize: 12).fontFamily,
        ...?emojiTextStyle(fontSize: 12).fontFamilyFallback,
      ];
      expect(families, contains('Noto Color Emoji'));
      expect(families, contains('Apple Color Emoji'));
      expect(families, contains('Segoe UI Emoji'));
    });

    test('keeps the caller\'s size and colour', () {
      final style = emojiTextStyle(fontSize: 18, color: Colors.red);
      expect(style.fontSize, 18);
      expect(style.color, Colors.red);
    });
  });

  group('reaction choices', () {
    test('every choice is a single emoji, with no stray whitespace', () {
      expect(feedReactionEmojiChoices, isNotEmpty);
      for (final emoji in feedReactionEmojiChoices) {
        expect(emoji, emoji.trim());
        expect(emoji, isNotEmpty);
      }
    });

    test('choices are distinct, so the picker cannot show a duplicate', () {
      expect(
        feedReactionEmojiChoices.toSet().length,
        feedReactionEmojiChoices.length,
      );
    });
  });

  group('ShimmerImage', () {
    testWidgets('shows a still placeholder, not a shimmer sweep',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerImage(imageUrl: 'https://example.com/a.jpg'),
          ),
        ),
      );
      await tester.pump();

      // Nothing in the loading state may animate: the whole point of the
      // change was to stop feed images sweeping while they load.
      expect(find.byType(AnimatedWidget), findsNothing);
      expect(find.byType(ColoredBox), findsWidgets);
    });

    testWidgets('an asset path renders without a network fetch',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerImage(imageUrl: 'assets/does-not-matter.png'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
    });

    test('the fade is short enough not to feel like a transition', () {
      expect(appImageFadeDuration.inMilliseconds, lessThanOrEqualTo(400));
      expect(appImageFadeDuration, greaterThan(Duration.zero));
    });
  });
}
