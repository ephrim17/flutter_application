import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/daily_verse_providers.dart';
import 'package:flutter_application/church_app/providers/language_provider.dart';
import 'package:flutter_application/church_app/widgets/language_toggle_widget.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/screens/for_you/sections/daily_verse_section.dart';
import 'package:flutter_application/church_app/widgets/decorated_scripture_card_widget.dart';

/// The Daily Verse card shows the verse as text in whichever language the
/// toggle is set to, and its share icon offers the AI prompt builder or the
/// manual editor — the app no longer renders AI poster images itself.
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

Widget _harness() {
  return ProviderScope(
    overrides: [
      selectedChurchProvider.overrideWith((ref) => _church()),
      appConfigProvider.overrideWith((ref) => Stream.value(_configWithVerse())),
      dailyVerseProviderLocal.overrideWith((ref) async => _verse),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: DailyVerseCard()),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the verse as text in the toggled language',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // The toggle defaults to Tamil.
    expect(find.textContaining('பலியிடுவேன்'), findsOneWidget);
    expect(find.text('யோனா 2:9'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('the language toggle switches the verse', (tester) async {
    await tester.pumpWidget(_harness());
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

  testWidgets('the card carries no title of its own', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // "Daily verse" belongs above the card, as a section header, the same as
    // every other For You section. Only the section renders it; the card on
    // its own must not.
    expect(find.text('Daily verse'), findsNothing);
  });

  testWidgets('reference, language toggle and share sit below the verse',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final verseBottom =
        tester.getRect(find.textContaining('பலியிடுவேன்')).bottom;
    for (final control in <Finder>[
      find.byType(ScriptureReferencePill),
      find.byType(BibleLanguageToggle),
      find.byIcon(Icons.share_outlined),
    ]) {
      expect(
        tester.getRect(control).top,
        greaterThanOrEqualTo(verseBottom),
        reason: '$control must be in the bottom bar, not above the verse',
      );
    }
  });

  testWidgets('the bottom bar reads reference, then language, then share',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final reference = tester.getRect(find.byType(ScriptureReferencePill));
    final toggle = tester.getRect(find.byType(BibleLanguageToggle));
    final share = tester.getRect(find.byIcon(Icons.share_outlined));

    expect(reference.left, lessThan(toggle.left));
    expect(toggle.left, lessThan(share.left));
    // One bar: all three share a line rather than stacking.
    expect((toggle.center.dy - share.center.dy).abs(), lessThan(1));
    expect((reference.center.dy - toggle.center.dy).abs(), lessThan(1));
  });

  testWidgets('share offers the AI prompt builder and the manual editor',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.share_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Create an AI prompt'), findsOneWidget);
    expect(find.text('Create manually'), findsOneWidget);
    expect(find.text('Generate with AI'), findsNothing);
  });
}
