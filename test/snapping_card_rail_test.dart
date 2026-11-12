import 'package:flutter_application/church_app/widgets/snapping_card_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rail takes its height from its tallest card and gives every card
/// that height. Without it, a prayer request with a one-line description
/// sat next to one with three and the two cards ended on different bottom
/// edges — the same content at two different sizes, side by side.
void main() {
  Future<void> pumpRail(
    WidgetTester tester, {
    required List<double> cardHeights,
    double width = 1251,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SnappingCardRail(
              itemCount: cardHeights.length,
              itemBuilder: (_, index) => Container(
                key: ValueKey<int>(index),
                // The card's own content height, which the rail overrides.
                constraints: BoxConstraints(minHeight: cardHeights[index]),
                color: Colors.blue,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect cardRect(WidgetTester tester, int index) =>
      tester.getRect(find.byKey(ValueKey<int>(index)));

  group('every card is the same size', () {
    testWidgets('a short card is given the tallest card\'s height',
        (tester) async {
      await pumpRail(tester, cardHeights: [120, 260, 180]);

      expect(cardRect(tester, 0).height, 260);
      expect(cardRect(tester, 1).height, 260);
      expect(cardRect(tester, 2).height, 260);
    });

    testWidgets('and they all start on the same top edge', (tester) async {
      await pumpRail(tester, cardHeights: [120, 260]);

      expect(cardRect(tester, 0).top, cardRect(tester, 1).top);
      expect(cardRect(tester, 0).bottom, cardRect(tester, 1).bottom);
    });

    testWidgets('they are all the same width too', (tester) async {
      await pumpRail(tester, cardHeights: [120, 260, 180]);

      expect(cardRect(tester, 1).width, cardRect(tester, 0).width);
      expect(cardRect(tester, 2).width, cardRect(tester, 0).width);
    });
  });

  group('the next card is visible past the edge', () {
    testWidgets('a lone card takes the full gutter width, with no peek',
        (tester) async {
      await pumpRail(tester, cardHeights: [120], width: 1000);

      // 1000 - 16 either side, and nothing held back for a card that is
      // not there.
      expect(cardRect(tester, 0).width, 968);
    });

    testWidgets('with more than one, room is left for the next',
        (tester) async {
      await pumpRail(tester, cardHeights: [120, 120], width: 1000);

      expect(cardRect(tester, 0).width, 968 - 30);
      // The second card starts before the right edge, so it is cut off
      // rather than being entirely off-screen.
      expect(cardRect(tester, 1).left, lessThan(1000));
    });
  });

  group('the dots', () {
    testWidgets('are absent for a single card', (tester) async {
      await pumpRail(tester, cardHeights: [120]);
      expect(find.byType(SnappingRailDots), findsNothing);
    });

    testWidgets('are one per card and tappable', (tester) async {
      await pumpRail(tester, cardHeights: [120, 120, 120]);

      final dots = find.descendant(
        of: find.byType(SnappingRailDots),
        matching: find.byType(GestureDetector),
      );
      expect(dots, findsNWidgets(3));

      final before = cardRect(tester, 0).left;
      await tester.tap(dots.at(2));
      await tester.pumpAndSettle();

      expect(
        cardRect(tester, 0).left,
        lessThan(before),
        reason: 'tapping the last dot scrolls the rail along',
      );
    });
  });

  group('a pointer gets arrows, as on the Home carousels', () {
    Finder nextArrow() => find.byIcon(Icons.chevron_right_rounded);
    Finder previousArrow() => find.byIcon(Icons.chevron_left_rounded);

    testWidgets('none below 700, so the touch layout is untouched',
        (tester) async {
      await pumpRail(tester, cardHeights: [120, 120], width: 699);
      expect(nextArrow(), findsNothing);
      expect(previousArrow(), findsNothing);
    });

    testWidgets('none for a single card either', (tester) async {
      await pumpRail(tester, cardHeights: [120], width: 1251);
      expect(nextArrow(), findsNothing);
    });

    testWidgets('from 700 up, pressing next moves the rail along',
        (tester) async {
      await pumpRail(tester, cardHeights: [120, 120, 120], width: 700);
      final before = cardRect(tester, 0).left;

      await tester.tap(nextArrow());
      await tester.pumpAndSettle();

      expect(cardRect(tester, 0).left, lessThan(before));
      expect(cardRect(tester, 1).left, moreOrLessEquals(16, epsilon: 1));
    });

    testWidgets('and back again', (tester) async {
      await pumpRail(tester, cardHeights: [120, 120, 120], width: 1251);
      final start = cardRect(tester, 0).left;

      await tester.tap(nextArrow());
      await tester.pumpAndSettle();
      await tester.tap(previousArrow());
      await tester.pumpAndSettle();

      expect(cardRect(tester, 0).left, moreOrLessEquals(start, epsilon: 1));
    });

    testWidgets('the arrows stay put at the ends rather than vanishing',
        (tester) async {
      await pumpRail(tester, cardHeights: [120, 120], width: 1251);
      expect(previousArrow(), findsOneWidget); // on the first card

      await tester.tap(nextArrow());
      await tester.pumpAndSettle();
      final atEnd = cardRect(tester, 0).left;

      expect(nextArrow(), findsOneWidget); // on the last card
      await tester.tap(nextArrow());
      await tester.pumpAndSettle();

      expect(
        cardRect(tester, 0).left,
        moreOrLessEquals(atEnd, epsilon: 1),
        reason: 'the dimmed arrow does nothing',
      );
    });
  });
}
