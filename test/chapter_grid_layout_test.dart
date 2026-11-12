import 'package:flutter_application/church_app/screens/side_drawer/bible_book_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The chapter picker must look the same on a phone and on a desktop: a
/// tile the size of a tile, with a wider screen simply fitting more per
/// row. It used to use five fixed columns at a 1.2 aspect ratio, so the
/// tile grew with the window — roughly 370 by 300 around a single numeral
/// on a full-width desktop route, and cramped at five across on a phone.
void main() {
  Future<List<Rect>> pumpGrid(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: chapterGridDelegate,
            itemCount: 50, // Genesis
            itemBuilder: (_, index) => SizedBox.expand(
              key: ValueKey<int>(index),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    return [
      for (var index = 0; index < 5; index++)
        tester.getRect(find.byKey(ValueKey<int>(index))),
    ];
  }

  for (final width in [320.0, 393.0, 606.0, 1100.0, 1512.0]) {
    testWidgets('a tile stays tile-sized at $width', (tester) async {
      final tiles = await pumpGrid(tester, width);
      final tile = tiles.first;

      expect(
        tile.height,
        moreOrLessEquals(64, epsilon: 0.5),
        reason: 'tile height is fixed, not derived from the window',
      );
      expect(
        tile.width,
        lessThanOrEqualTo(84.5),
        reason: 'a tile must never grow into a panel at $width',
      );
      expect(
        tile.width,
        greaterThan(40),
        reason: 'nor be squeezed to nothing at $width',
      );
    });
  }

  testWidgets('a wider window fits more per row, it does not inflate tiles',
      (tester) async {
    final narrow = await pumpGrid(tester, 393);
    final wide = await pumpGrid(tester, 1512);

    // Same tile size either way.
    expect(wide.first.width, moreOrLessEquals(narrow.first.width, epsilon: 20));
    expect(
        wide.first.height, moreOrLessEquals(narrow.first.height, epsilon: 1));

    int columnsIn(List<Rect> tiles) =>
        tiles.where((r) => r.top == tiles.first.top).length;

    // Five tiles are sampled, so a narrow screen cannot fit all five on one
    // row while a wide one can — that difference is the whole point.
    expect(columnsIn(narrow), lessThan(5));
    expect(columnsIn(wide), 5);
  });

  testWidgets('tiles stay inside the screen at the narrowest width',
      (tester) async {
    final tiles = await pumpGrid(tester, 320);
    for (final tile in tiles) {
      expect(tile.left, greaterThanOrEqualTo(-0.5));
      expect(tile.right, lessThanOrEqualTo(320.5));
    }
  });
}
