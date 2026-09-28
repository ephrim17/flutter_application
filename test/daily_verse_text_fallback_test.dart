import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/daily_verse_providers.dart';
import 'package:flutter_application/church_app/providers/language_provider.dart';
import 'package:flutter_application/church_app/widgets/language_toggle_widget.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/daily_verse_section.dart';

/// The Daily Verse card's last-resort state: when the church has no generated
/// cards for today *and* none on any earlier day the server falls back to, the
/// section shows the verse as plain text rather than an apology, with the
/// language toggle still driving it.
const _verse = {
  'english': 'But I will sacrifice to you with the voice of thanksgiving.',
  'reference': 'Jonah 2:9',
  'tamil': 'நானோவென்றால் துதியின் சத்தத்தோடே உமக்குப் பலியிடுவேன்.',
  'referenceTamil': 'யோனா 2:9',
};

Church _church() => Church(
      id: 'tnbm',
      name: 'Test Church',
      address: '',
      contact: '',
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

AppConfig _configWithVerse() {
  final fallback = AppConfig.fallback();
  return AppConfig(
    admins: fallback.admins,
    maxAdminCount: fallback.maxAdminCount,
    membersEnabled: fallback.membersEnabled,
    eventsEnabled: fallback.eventsEnabled,
    dashboardEnabled: fallback.dashboardEnabled,
    financialDashboardEnabled: fallback.financialDashboardEnabled,
    equipmentEnabled: fallback.equipmentEnabled,
    studioEnabled: fallback.studioEnabled,
    globalFeedEnabled: fallback.globalFeedEnabled,
    onboardingTitle: fallback.onboardingTitle,
    onboardingSubtitle: fallback.onboardingSubtitle,
    dailyVerseRef: DailyVerseRef(book: 'Jonah', chapter: 2, verse: 9),
    promiseVerseRef: fallback.promiseVerseRef,
    promptSheet: fallback.promptSheet,
    adminMode: fallback.adminMode,
    superAdminDisabled: fallback.superAdminDisabled,
    bibleSwipeFetchEnabled: fallback.bibleSwipeFetchEnabled,
    bibleSwipeFetchVersion: fallback.bibleSwipeFetchVersion,
    textContent: fallback.textContent,
    churchLogo: fallback.churchLogo,
    youtubeLink: fallback.youtubeLink,
  );
}

Widget _harness({required List<PickedImageData> cards}) {
  return ProviderScope(
    overrides: [
      selectedChurchProvider.overrideWith((ref) => _church()),
      appConfigProvider.overrideWith((ref) => Stream.value(_configWithVerse())),
      dailyVerseProviderLocal.overrideWith((ref) async => _verse),
      dailyVerseCardsProvider.overrideWith((ref, key) async => cards),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: DailyVerseCard()),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the verse as text when there are no cards at all',
      (tester) async {
    await tester.pumpWidget(_harness(cards: const []));
    await tester.pumpAndSettle();

    // The toggle defaults to Tamil, so that is the language the fallback
    // renders without any interaction.
    expect(find.textContaining('பலியிடுவேன்'), findsOneWidget);
    expect(find.text('யோனா 2:9'), findsOneWidget);
    // The "not created yet" apology is what this replaced.
    expect(find.textContaining("haven't been created yet"), findsNothing);
  });

  testWidgets('the language toggle drives the text fallback', (tester) async {
    await tester.pumpWidget(_harness(cards: const []));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyVerseCard)),
    );
    container.read(dailyVerseLanguageProvider.notifier).state =
        BibleLanguage.english;
    await tester.pumpAndSettle();

    expect(find.textContaining('voice of thanksgiving'), findsOneWidget);
    expect(find.text('Jonah 2:9'), findsOneWidget);
    expect(find.text('யோனா 2:9'), findsNothing);
  });

  testWidgets('cards win over the text fallback when the church has them',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        cards: [
          PickedImageData(bytes: _pngPixel, name: 'card'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('பலியிடுவேன்'), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
  });
}

/// Smallest decodable PNG — a 1x1 transparent pixel.
final _pngPixel = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);
