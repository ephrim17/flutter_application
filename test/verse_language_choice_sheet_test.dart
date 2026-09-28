import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/widgets/modals/verse_share_modal.dart';

/// Opens the sheet and records what it resolved to, so each test can assert on
/// the caller-visible result rather than on which tile was tapped.
Future<void> _pumpSheetHost(
  WidgetTester tester,
  List<VerseShareLanguage?> results,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              results.add(await showVerseLanguageChoiceSheet(context));
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('verse language sheet offers English and Tamil', (tester) async {
    await _pumpSheetHost(tester, <VerseShareLanguage?>[]);

    expect(find.text('Share in English'), findsOneWidget);
    expect(find.text('Share in Tamil'), findsOneWidget);
  });

  testWidgets('tapping English resolves to English and closes the sheet',
      (tester) async {
    final results = <VerseShareLanguage?>[];
    await _pumpSheetHost(tester, results);

    await tester.tap(find.text('Share in English'));
    await tester.pumpAndSettle();

    expect(results, <VerseShareLanguage?>[VerseShareLanguage.english]);
    expect(find.text('Share in English'), findsNothing);
  });

  testWidgets('tapping Tamil resolves to Tamil and closes the sheet',
      (tester) async {
    final results = <VerseShareLanguage?>[];
    await _pumpSheetHost(tester, results);

    await tester.tap(find.text('Share in Tamil'));
    await tester.pumpAndSettle();

    // Regression guard: the Favourites screen's equivalent sheet leaves itself
    // open on the Tamil branch, so assert this one actually closes.
    expect(results, <VerseShareLanguage?>[VerseShareLanguage.tamil]);
    expect(find.text('Share in Tamil'), findsNothing);
  });

  testWidgets('dismissing the sheet resolves to null, not a default language',
      (tester) async {
    final results = <VerseShareLanguage?>[];
    await _pumpSheetHost(tester, results);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Callers spend the user's daily AI quota on this answer — a dismissal
    // must never silently generate in some default script.
    expect(results, <VerseShareLanguage?>[null]);
  });
}
