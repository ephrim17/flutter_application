import 'package:flutter_application/church_app/screens/for_you/for_you_card_layout.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// For You had no width cap at all: on a desktop window every card stretched
/// to the full window while Home's cards capped themselves and centred, so
/// switching tabs changed the page's whole shape.
///
/// The cap is expressed in terms of Home's card width rather than a second
/// magic number, so the two tabs land on the same edges by construction.
/// Each section pads itself by [forYouSidePadding] inside this box, which is
/// why the box is that much wider than the card it should produce.
void main() {
  Future<Rect> pumpAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForYouContentWidth(
            child: Container(
              key: const ValueKey('content'),
              height: 100,
              color: const Color(0xFF000000),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    return tester.getRect(find.byKey(const ValueKey('content')));
  }

  testWidgets('a phone is left alone — the content still fills the width',
      (tester) async {
    final content = await pumpAt(tester, 411);

    expect(content.left, moreOrLessEquals(0, epsilon: 0.5));
    expect(content.width, moreOrLessEquals(411, epsilon: 0.5));
  });

  testWidgets('a desktop window caps the content and centres it',
      (tester) async {
    final content = await pumpAt(tester, 1280);

    expect(content.width, lessThan(1280));
    expect(
      content.center.dx,
      moreOrLessEquals(640, epsilon: 0.5),
      reason: 'content should be centred in the window',
    );
  });

  testWidgets('a For You card lands on the same edge as a Home card',
      (tester) async {
    const width = 1280.0;
    final content = await pumpAt(tester, width);

    // What a section actually draws, once it has applied its own gutter.
    final cardLeft = content.left + forYouSidePadding;
    final cardRight = content.right - forYouSidePadding;

    // Where Home puts its card: centred content column, inset by the amount
    // a carousel page insets its page.
    final columnWidth = homeSectionMaxWidth(width)!;
    final homeCardLeft =
        (width - columnWidth) / 2 + homeCarouselCardInset(width);
    final homeCardRight = homeCardLeft + homeCardWidth(width);

    expect(cardLeft, moreOrLessEquals(homeCardLeft, epsilon: 0.5));
    expect(cardRight, moreOrLessEquals(homeCardRight, epsilon: 0.5));
  });
}
