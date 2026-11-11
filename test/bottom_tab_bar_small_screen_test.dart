import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_bottom_tab_bar.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bottom tab bar is the app's only navigation and carries four tabs
/// for an admin: Home, For You, Messages, Dashboard. At narrow widths the
/// labels are `maxLines: 1` with `TextOverflow.ellipsis`, so a squeeze
/// produces no error — the text quietly becomes "Dashboa…".
///
/// These widths are real Android screens: 320dp is the narrow end still in
/// use, 360dp is the most common Android width in the world, 412dp is a
/// Pixel.
///
/// **This file deliberately does not assert whether a label is
/// ellipsized.** The app takes its fonts from `google_fonts` at runtime, so
/// a widget test has no real font and falls back to a placeholder whose
/// every glyph is a square of the font size — "For You" measures ~80px in a
/// test and nothing like that on a device. Any truncation threshold written
/// here would be measuring the test harness. Readability at small widths is
/// checked on a real device instead; what is asserted below is what the
/// test environment can actually answer.
void main() {
  const widths = <double>[320, 360, 375, 412];

  const labels = <String>['Home', 'For You', 'Messages', 'Dashboard'];

  List<AppBottomTabItem> buildItems() => const [
        AppBottomTabItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Home',
        ),
        AppBottomTabItem(
          icon: Icons.star_outline_rounded,
          selectedIcon: Icons.star_rounded,
          label: 'For You',
        ),
        AppBottomTabItem(
          icon: Icons.forum_outlined,
          selectedIcon: Icons.forum_rounded,
          label: 'Messages',
        ),
        AppBottomTabItem(
          icon: Icons.dashboard_customize_outlined,
          selectedIcon: Icons.dashboard_customize_rounded,
          label: 'Dashboard',
        ),
      ];

  Future<void> pumpAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomTabBar(
            currentIndex: 0,
            items: buildItems(),
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final width in widths) {
    testWidgets('all four tabs render without overflow at ${width.toInt()}dp',
        (tester) async {
      await pumpAt(tester, width);
      expect(
        tester.takeException(),
        isNull,
        reason: 'the bar overflowed at ${width.toInt()}dp',
      );

      for (final label in labels) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '$label is missing at ${width.toInt()}dp',
        );
      }

      // Each tab gets an equal share and none collapses to nothing.
      final tabWidths = <double>[
        for (var index = 0; index < labels.length; index++)
          tester
              .getRect(find.byKey(ValueKey<String>('app-bottom-tab-$index')))
              .width,
      ];
      expect(tabWidths.reduce((a, b) => a < b ? a : b), greaterThan(0));
      expect(
        (tabWidths.reduce((a, b) => a > b ? a : b) -
                tabWidths.reduce((a, b) => a < b ? a : b))
            .abs(),
        lessThan(1),
        reason: 'tabs should share the width evenly',
      );
    });
  }

  testWidgets('the whole bar stays on screen at the narrowest width',
      (tester) async {
    await pumpAt(tester, 320);

    final bar = tester.getRect(find.byType(AppBottomTabBar));
    expect(bar.left, greaterThanOrEqualTo(0));
    expect(bar.right, lessThanOrEqualTo(320));

    // Every tab keeps a tappable target. 48dp is the accessibility floor,
    // and a 4-tab bar on a 320dp phone is where that gets squeezed.
    for (var index = 0; index < labels.length; index++) {
      final tab = tester.getRect(
        find.byKey(ValueKey<String>('app-bottom-tab-$index')),
      );
      expect(
        tab.height,
        greaterThanOrEqualTo(48),
        reason: 'tab $index is shorter than a 48dp touch target',
      );
      expect(tab.left, greaterThanOrEqualTo(0));
      expect(tab.right, lessThanOrEqualTo(320));
    }
  });
}
