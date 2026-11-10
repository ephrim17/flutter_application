import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_card_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// A For You section that has nothing to show renders `SizedBox.shrink()`.
/// The page used to put its 24dp between-sections gap in front of every
/// section regardless, so each silent section left a band of empty page
/// behind it. On a real church two of them sat between Daily Verse and
/// Pray for Others, and the gap there measured 104dp against the 33dp
/// between Pray and Featured.
void main() {
  Future<Rect> rectOf(
    WidgetTester tester,
    List<Widget> children,
    Key key,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              for (final child in children) SliverToBoxAdapter(child: child),
            ],
          ),
        ),
      ),
    );
    return tester.getRect(find.byKey(key));
  }

  Widget block(String id, double height) => ForYouSectionSpacing(
        child: SizedBox(key: ValueKey(id), height: height, width: 100),
      );

  testWidgets('a section that renders nothing takes up no space at all',
      (tester) async {
    final withoutEmpty = await rectOf(
      tester,
      [block('a', 50), block('b', 50)],
      const ValueKey('b'),
    );

    final withEmpty = await rectOf(
      tester,
      [
        block('a', 50),
        // Three sections that have no content today.
        ForYouSectionSpacing(child: const SizedBox.shrink()),
        ForYouSectionSpacing(child: const SizedBox.shrink()),
        ForYouSectionSpacing(child: const SizedBox.shrink()),
        block('b', 50),
      ],
      const ValueKey('b'),
    );

    expect(
      withEmpty.top,
      withoutEmpty.top,
      reason: 'empty sections must not push the next section down',
    );
  });

  testWidgets('every rendered section gets the same gap above it',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              for (final child in [
                block('a', 50),
                ForYouSectionSpacing(child: const SizedBox.shrink()),
                block('b', 50),
                block('c', 50),
              ])
                SliverToBoxAdapter(child: child),
            ],
          ),
        ),
      ),
    );

    final a = tester.getRect(find.byKey(const ValueKey('a')));
    final b = tester.getRect(find.byKey(const ValueKey('b')));
    final c = tester.getRect(find.byKey(const ValueKey('c')));

    // The gap either side of the silent section is the same as any other.
    expect(b.top - a.bottom, forYouSectionGap);
    expect(c.top - b.bottom, forYouSectionGap);
  });

  testWidgets('the gap is above the content, not below it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [SliverToBoxAdapter(child: block('a', 50))],
          ),
        ),
      ),
    );
    final a = tester.getRect(find.byKey(const ValueKey('a')));
    expect(a.top, forYouSectionGap);
    expect(a.height, 50);
  });
}
