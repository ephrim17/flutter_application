import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/helpers/verse_poster_prompt.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/widgets/modals/verse_prompt_builder_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Captured from the reference builder (tcsong.com/prompteasy/DBVPoster1.html)
// rendered with its own example values, so the app's prompt stays word-for-word
// what that page produces.
const _referenceDefault =
    '''You are a world-class senior graphic designer. Create ONE finished daily Bible-verse poster.

FORMAT
• Portrait 9:16 (1080 × 1920) — WhatsApp status, Reels, Stories. Full-bleed, print-quality, sharp and readable on a phone.
• Render style: Cinematic photoreal — film lighting, depth of field, volumetric rays. Mood: peaceful and hopeful.
• No watermark, no extra text, no stickers, no border frame unless described below.

BACKGROUND
• Colour theme: Golden Sunrise — warm gold, amber, soft peach.
• Scene: Green pasture beside still waters at sunrise, a shepherd silhouette in the distance, soft golden light rays.
• Keep the area behind the verse calm and uncluttered so the text is perfectly legible.

TOP OF POSTER
• small elegant uppercase label with thin gold lines on each side, reading exactly: Daily Bread · Living Word Ministries

THE VERSE (main element)
• Language: English. Font size: large — about 8% of the poster height, bold and commanding.
• Position: centred in the upper-middle of the poster.
• Text style: pure white serif with a soft black drop shadow.
• Verse text, line breaks EXACTLY as written:
The LORD is my shepherd; I shall not want.
• Reference in a DIFFERENT colour from the verse — gold small caps in a thin pill below the verse, reading exactly: Psalm 23:1 (NKJV)

FOOTER (bottom of poster)
• thin elegant strip with logo left, name centre, contact right.
• Ministry name exactly: Living Word Ministries
• Contact exactly: +91 00000 00000 · www.example.org

EXACT TEXT — CRITICAL
Every word above must be rendered letter-for-letter exactly as given, in the given language and script — same spelling, vowel signs, punctuation and line breaks. Do NOT translate, transliterate, shorten, "correct", repeat or add any word. Verify each line before finishing; if a character cannot be drawn perfectly, redraw that line rather than approximate it.

DESIGN QUALITY
Clear hierarchy (verse > reference > top name > footer), balanced grid, consistent theme colours, text never over faces, no cropped glyphs. Professional, premium, world-class finish.''';

const _referenceAllSections =
    '''You are a world-class senior graphic designer. Create ONE finished daily Bible-verse poster.

FORMAT
• Portrait 9:16 (1080 × 1920) — WhatsApp status, Reels, Stories. Full-bleed, print-quality, sharp and readable on a phone.
• Render style: Cinematic photoreal — film lighting, depth of field, volumetric rays. Mood: peaceful and hopeful.
• No watermark, no extra text, no stickers, no border frame unless described below.

BACKGROUND
• Colour theme: Golden Sunrise — warm gold, amber, soft peach.
• Scene: Green pasture beside still waters at sunrise, a shepherd silhouette in the distance, soft golden light rays.
• Keep the area behind the verse calm and uncluttered so the text is perfectly legible.

TOP OF POSTER
• small elegant uppercase label with thin gold lines on each side, reading exactly: Daily Bread · Living Word Ministries
• Date — small pill badge in the top-right corner, reading exactly: Monday, 9 November 2026

TITLE (directly above the verse)
• bold display type in the theme's accent colour, larger than the reference but smaller than the verse, reading exactly: TITLEX

THE VERSE (main element)
• Language: English. Font size: large — about 8% of the poster height, bold and commanding.
• Position: centred in the upper-middle of the poster.
• Text style: pure white serif with a soft black drop shadow.
• Verse text, line breaks EXACTLY as written:
The LORD is my shepherd; I shall not want.
• Reference in a DIFFERENT colour from the verse — gold small caps in a thin pill below the verse, reading exactly: Psalm 23:1 (NKJV)

FOOTER (bottom of poster)
• thin elegant strip with logo left, name centre, contact right.
• Ministry name exactly: Living Word Ministries
• Contact exactly: +91 00000 00000 · www.example.org
• I have attached my logo: place it in the footer at its original colours and proportions, unchanged, not redrawn.

EXACT TEXT — CRITICAL
Every word above must be rendered letter-for-letter exactly as given, in the given language and script — same spelling, vowel signs, punctuation and line breaks. Do NOT translate, transliterate, shorten, "correct", repeat or add any word. Verify each line before finishing; if a character cannot be drawn perfectly, redraw that line rather than approximate it.

DESIGN QUALITY
Clear hierarchy (verse > reference > top name > footer), balanced grid, consistent theme colours, text never over faces, no cropped glyphs. Professional, premium, world-class finish.''';

const _example = VersePosterPromptOptions(
  verseText: 'The LORD is my shepherd; I shall not want.',
  reference: 'Psalm 23:1 (NKJV)',
  topName: 'Daily Bread · Living Word Ministries',
  useFooter: true,
  ministry: 'Living Word Ministries',
  contact: '+91 00000 00000 · www.example.org',
);

Church _church() => Church(
      id: 'tnbm',
      name: 'Grace Church',
      address: '',
      contact: '+91 98765 43210',
      email: '',
      pastorName: '',
      pastorPhoto: '',
      logo: '',
      enabled: true,
      registrationSource: '',
      approvalStatus: 'approved',
      facebookLink: '',
      instagramLink: '',
      youtubeLink: '',
    );

void main() {
  group('buildVersePosterPrompt', () {
    test('matches the reference builder for its example', () {
      expect(buildVersePosterPrompt(_example), _referenceDefault);
    });

    test('matches the reference builder with every optional section on', () {
      final prompt = buildVersePosterPrompt(
        VersePosterPromptOptions(
          verseText: _example.verseText,
          reference: _example.reference,
          topName: _example.topName,
          useDate: true,
          dateText: formatVersePosterDate(
            DateTime(2026, 11, 9),
            VersePosterDateFormat.long,
          ),
          useTitle: true,
          title: 'TITLEX',
          useFooter: true,
          ministry: _example.ministry,
          contact: _example.contact,
          useLogo: true,
        ),
      );
      expect(prompt, _referenceAllSections);
    });

    test('drops the top section when there is no name and no date', () {
      final prompt = buildVersePosterPrompt(
        const VersePosterPromptOptions(verseText: 'v', reference: 'r'),
      );
      expect(prompt, isNot(contains('TOP OF POSTER')));
      expect(prompt, isNot(contains('FOOTER')));
    });

    test('keeps verse line breaks but strips blank and padded lines', () {
      final prompt = buildVersePosterPrompt(
        const VersePosterPromptOptions(
          verseText: '  line one  \n\n   line two\n',
          reference: 'r',
        ),
      );
      expect(prompt, contains('EXACTLY as written:\nline one\nline two\n'));
    });

    test('formats each date style', () {
      final date = DateTime(2026, 11, 3);
      expect(
        formatVersePosterDate(date, VersePosterDateFormat.long),
        'Tuesday, 3 November 2026',
      );
      expect(
        formatVersePosterDate(date, VersePosterDateFormat.short),
        '03 Nov 2026',
      );
      expect(
        formatVersePosterDate(date, VersePosterDateFormat.numeric),
        '03-11-2026',
      );
      expect(
        formatVersePosterDate(date, VersePosterDateFormat.monthFirst),
        'NOV 3 · Tuesday',
      );
    });
  });

  group('VersePromptBuilderScreen', () {
    Future<List<String>> pump(
      WidgetTester tester, {
      required String text,
      bool isGuestShare = false,
    }) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedChurchProvider.overrideWith((ref) => _church()),
          ],
          child: MaterialApp(
            home: VersePromptBuilderScreen(
              text: text,
              reference: 'Ref 1:1',
              isGuestShare: isGuestShare,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return copied;
    }

    testWidgets('prefills the church and copies the prompt', (tester) async {
      final copied = await pump(tester, text: 'Rejoice always.');

      await tester.tap(find.text('Copy prompt'));
      await tester.pumpAndSettle();

      expect(copied, hasLength(1));
      expect(copied.single, contains('reading exactly: Grace Church'));
      expect(copied.single, contains('Contact exactly: +91 98765 43210'));
      expect(copied.single, contains('Language: English.'));
      expect(copied.single, contains('Rejoice always.'));
      expect(find.textContaining('Prompt copied'), findsOneWidget);
    });

    testWidgets('detects a Tamil verse', (tester) async {
      final copied = await pump(tester, text: 'எப்பொழுதும் சந்தோஷமாயிருங்கள்.');

      await tester.tap(find.text('Copy prompt'));
      await tester.pumpAndSettle();

      expect(copied.single, contains('Language: Tamil (Tamil script).'));
    });

    testWidgets('a guest share carries no church branding', (tester) async {
      final copied = await pump(
        tester,
        text: 'Rejoice always.',
        isGuestShare: true,
      );

      await tester.tap(find.text('Copy prompt'));
      await tester.pumpAndSettle();

      expect(copied.single, isNot(contains('Grace Church')));
      expect(copied.single, isNot(contains('98765')));
    });
  });
}
