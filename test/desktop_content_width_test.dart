import 'package:flutter_application/church_app/widgets/desktop_content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lists, forms and tables get a readable cap on a wide window; cards and
/// pictures (Home, For You) deliberately do not and are not covered here.
///
/// The rule that matters most is the negative one: below the cap this must
/// change nothing at all, or it would quietly reshape every phone and
/// tablet screen it was applied to.
void main() {
  group('DesktopContentWidth', () {
    Future<Rect> pumpAt(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopContentWidth(
              child: Container(
                key: const ValueKey('content'),
                height: 200,
                color: const Color(0xFF000000),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getRect(find.byKey(const ValueKey('content')));
    }

    test('the cap is a readable width, not a narrow column', () {
      // Wide enough that a member row's name and its trailing control stay
      // in one comfortable scan.
      expect(desktopReadableWidth, greaterThanOrEqualTo(900));
      expect(desktopReadableWidth, lessThanOrEqualTo(1300));
    });

    testWidgets('a phone is untouched', (tester) async {
      final content = await pumpAt(tester, 393);
      expect(content.left, moreOrLessEquals(0, epsilon: 0.5));
      expect(content.width, moreOrLessEquals(393, epsilon: 0.5));
    });

    testWidgets('a tablet in landscape is untouched', (tester) async {
      final content = await pumpAt(tester, 1024);
      expect(content.width, moreOrLessEquals(1024, epsilon: 0.5));
    });

    testWidgets('just below the cap is untouched', (tester) async {
      final content = await pumpAt(tester, desktopReadableWidth - 1);
      expect(
        content.width,
        moreOrLessEquals(desktopReadableWidth - 1, epsilon: 0.5),
      );
    });

    testWidgets('a wide window caps and centres', (tester) async {
      final content = await pumpAt(tester, 1600);
      expect(content.width, moreOrLessEquals(desktopReadableWidth, epsilon: 1));
      expect(content.center.dx, moreOrLessEquals(800, epsilon: 1));
    });

    testWidgets('content sits at the top, not floating mid-page',
        (tester) async {
      final content = await pumpAt(tester, 1600);
      expect(content.top, moreOrLessEquals(0, epsilon: 0.5));
    });
  });

  group('statGridColumns', () {
    test('a phone keeps two across', () {
      expect(statGridColumns(320), 2);
      expect(statGridColumns(393), 2);
      expect(statGridColumns(430), 2);
    });

    test('a tablet gets three', () {
      expect(statGridColumns(768), 3);
      expect(statGridColumns(900), 3);
    });

    test('a desktop gets four, and no more than four', () {
      expect(statGridColumns(1024), 4);
      expect(statGridColumns(1600), 4);
      // Four figures spread across a very wide window would read as a thin
      // line of unrelated numbers, so the count stops here.
      expect(statGridColumns(2560), 4);
    });

    test('never more columns than there are things to show', () {
      expect(statGridColumns(1600, itemCount: 2), 2);
      expect(statGridColumns(1600, itemCount: 3), 3);
      expect(statGridColumns(320, itemCount: 1), 1);
    });

    test('a tile stays tile-shaped rather than becoming a panel', () {
      // The bug this replaced: two fixed columns at a 1.75 aspect ratio
      // gave each tile about 770 by 440 on a 1568 window.
      const available = 1100.0;
      final columns = statGridColumns(available);
      final tileWidth = (available - (columns - 1) * 10) / columns;
      expect(tileWidth, lessThan(300));
      expect(statGridTileHeight(columns), lessThan(tileWidth));
    });
  });
}
