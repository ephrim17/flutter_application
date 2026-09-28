import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/helpers/verse_image_generation_progress.dart';
import 'package:flutter_application/church_app/widgets/blocking_percent_progress_dialog.dart';

const _expected = Duration(seconds: 75);

double _progress({
  required int done,
  required Duration elapsed,
  int total = 2,
}) =>
    verseImageGenerationProgress(
      languagesDone: done,
      totalLanguages: total,
      elapsedInSegment: elapsed,
      expectedPerLanguage: _expected,
    );

void main() {
  group('verseImageGenerationProgress', () {
    test('starts at zero', () {
      expect(_progress(done: 0, elapsed: Duration.zero), 0);
    });

    test('creeps through the first language without reaching its segment', () {
      final early = _progress(done: 0, elapsed: const Duration(seconds: 20));
      final late = _progress(done: 0, elapsed: const Duration(seconds: 70));
      expect(early, greaterThan(0));
      expect(late, greaterThan(early));
      // Never claims the first language is done before it is.
      expect(late, lessThan(0.5));
    });

    test('a finished language fills its segment outright', () {
      expect(_progress(done: 1, elapsed: Duration.zero), 0.5);
    });

    test('holds just short of the milestone when a batch overruns', () {
      final atExpected =
          _progress(done: 0, elapsed: const Duration(seconds: 75));
      final wayOver = _progress(done: 0, elapsed: const Duration(minutes: 10));
      expect(wayOver, atExpected);
      expect(wayOver, lessThan(0.5));
    });

    test('never exceeds 1, and both languages done is exactly 1', () {
      expect(_progress(done: 2, elapsed: const Duration(minutes: 5)), 1);
      expect(_progress(done: 9, elapsed: const Duration(minutes: 5)), 1);
    });

    test('degenerate inputs stay in range rather than throwing', () {
      expect(_progress(done: 0, elapsed: Duration.zero, total: 0), 0);
      expect(
        verseImageGenerationProgress(
          languagesDone: 1,
          totalLanguages: 2,
          elapsedInSegment: const Duration(seconds: 10),
          expectedPerLanguage: Duration.zero,
        ),
        0.5,
      );
    });

    test('percent rounds the fraction for display', () {
      expect(verseImageGenerationPercent(0), 0);
      expect(verseImageGenerationPercent(0.5), 50);
      expect(verseImageGenerationPercent(0.567), 57);
      expect(verseImageGenerationPercent(1), 100);
      expect(verseImageGenerationPercent(2), 100);
    });
  });

  group('BlockingPercentProgressDialog', () {
    testWidgets('shows the percentage and the message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BlockingPercentProgressDialog(
              progress: 0.5,
              message: 'Creating verse images.',
            ),
          ),
        ),
      );

      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Creating verse images.'), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, 0.5);
    });

    testWidgets('cannot be dismissed by a back gesture', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BlockingPercentProgressDialog(
              progress: 0.2,
              message: 'Creating verse images.',
            ),
          ),
        ),
      );

      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    });
  });
}
