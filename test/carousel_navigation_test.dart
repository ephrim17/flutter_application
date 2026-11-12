import 'package:flutter_application/church_app/widgets/autoscroll_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A `PageView` only advances once a drag passes half a page. On a phone
/// that is a flick. On a desktop, where a card can be 1,300px wide, it
/// means dragging 650px with a mouse — and a wheel does not page it at all,
/// it drifts and springs back. So the dots could say "there are two of
/// these" while the second one stayed effectively unreachable.
///
/// Arrows are the pointer's way in, and the dots are tappable for everyone.
void main() {
  Future<void> pumpCarousel(
    WidgetTester tester, {
    required double width,
    required int itemCount,
    bool autoScroll = false,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AutoScrollCarousel(
            height: 240,
            itemCount: itemCount,
            autoScroll: autoScroll,
            itemBuilder: (_, index) => Center(child: Text('card $index')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Unmounts the carousel and lets its pending auto-advance delay fire, so
  /// the loop sees `!mounted` and stops rather than outliving the test.
  Future<void> stopAutoScroll(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  Finder nextArrow() => find.byIcon(Icons.chevron_right_rounded);
  Finder previousArrow() => find.byIcon(Icons.chevron_left_rounded);

  group('a single card needs no navigation at all', () {
    testWidgets('no arrows and no dots, at any width', (tester) async {
      await pumpCarousel(tester, width: 1512, itemCount: 1);
      expect(nextArrow(), findsNothing);
      expect(previousArrow(), findsNothing);
    });
  });

  group('phones and tablets keep the touch treatment', () {
    for (final width in [320.0, 393.0, 606.0, 699.0]) {
      testWidgets('no arrows at $width', (tester) async {
        await pumpCarousel(tester, width: width, itemCount: 3);
        expect(
          nextArrow(),
          findsNothing,
          reason: 'arrows would cover the card on a touch layout',
        );
      });
    }
  });

  group('a pointer gets arrows', () {
    testWidgets('from 700 up', (tester) async {
      await pumpCarousel(tester, width: 700, itemCount: 3);
      expect(nextArrow(), findsOneWidget);
      expect(previousArrow(), findsOneWidget);
    });

    testWidgets('tapping next moves to the following card', (tester) async {
      await pumpCarousel(tester, width: 1512, itemCount: 3);
      expect(find.text('card 0'), findsOneWidget);

      await tester.tap(nextArrow());
      await tester.pumpAndSettle();

      expect(find.text('card 1'), findsOneWidget);
    });

    testWidgets('and back again', (tester) async {
      await pumpCarousel(tester, width: 1512, itemCount: 3);

      await tester.tap(nextArrow());
      await tester.pumpAndSettle();
      await tester.tap(previousArrow());
      await tester.pumpAndSettle();

      expect(find.text('card 0'), findsOneWidget);
    });

    testWidgets('the arrows stay put at the ends rather than vanishing',
        (tester) async {
      // A control that disappears is harder to aim at than one that greys
      // out, so both are always rendered; only the tap is withheld.
      await pumpCarousel(tester, width: 1512, itemCount: 2);
      expect(previousArrow(), findsOneWidget); // on the first card

      await tester.tap(nextArrow());
      await tester.pumpAndSettle();

      expect(nextArrow(), findsOneWidget); // on the last card
    });

    testWidgets('pressing next on the last card does nothing', (tester) async {
      await pumpCarousel(tester, width: 1512, itemCount: 2);

      await tester.tap(nextArrow());
      await tester.pumpAndSettle();
      expect(find.text('card 1'), findsOneWidget);

      await tester.tap(nextArrow());
      await tester.pumpAndSettle();

      expect(find.text('card 1'), findsOneWidget);
    });
  });

  testWidgets('the dots are tappable, which is the phone\'s way across',
      (tester) async {
    await pumpCarousel(tester, width: 393, itemCount: 3);
    expect(find.text('card 0'), findsOneWidget);

    // The dots are the last gesture detectors in the tree, one per card.
    final dots = find.byType(GestureDetector);
    expect(dots, findsNWidgets(3));

    await tester.tap(dots.at(2));
    await tester.pumpAndSettle();

    expect(find.text('card 2'), findsOneWidget);
  });

  group('auto-advance yields to the reader', () {
    // Announcements used to advance on a timer. It moved the card out from
    // under whoever was reading it as they scrolled Home, with nothing on
    // screen saying why — so Home no longer asks for it. Where it is asked
    // for, it has to stop the moment the reader takes the wheel.
    testWidgets('a carousel left alone does advance', (tester) async {
      await pumpCarousel(tester, width: 1512, itemCount: 3, autoScroll: true);
      expect(find.text('card 0'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('card 1'), findsOneWidget);
      await stopAutoScroll(tester);
    });

    testWidgets('but stops for good once a card has been chosen',
        (tester) async {
      await pumpCarousel(tester, width: 1512, itemCount: 3, autoScroll: true);

      await tester.tap(nextArrow());
      await tester.pumpAndSettle();
      expect(find.text('card 1'), findsOneWidget);

      await tester.pump(const Duration(seconds: 12));
      await tester.pumpAndSettle();

      expect(
        find.text('card 1'),
        findsOneWidget,
        reason: 'the timer must not take the carousel back',
      );
      await stopAutoScroll(tester);
    });

    testWidgets('and it is off unless a caller asks for it', (tester) async {
      await pumpCarousel(tester, width: 1512, itemCount: 3);

      await tester.pump(const Duration(seconds: 12));
      await tester.pumpAndSettle();

      expect(find.text('card 0'), findsOneWidget);
    });
  });
}
