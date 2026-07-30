import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/widgets/app_bottom_tab_bar.dart';

void main() {
  testWidgets('custom bottom tab bar reports taps and selected semantics',
      (tester) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: StatefulBuilder(
            builder: (context, setState) => AppBottomTabBar(
              currentIndex: selectedIndex,
              items: const [
                AppBottomTabItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                AppBottomTabItem(
                  icon: Icons.newspaper_outlined,
                  selectedIcon: Icons.newspaper_rounded,
                  label: 'Feeds',
                ),
              ],
              onTap: (index) => setState(() => selectedIndex = index),
            ),
          ),
        ),
      ),
    );

    final homeSemantics =
        tester.getSemantics(find.byKey(const ValueKey('app-bottom-tab-0')));
    expect(homeSemantics.label, 'Home');
    final homeWidget = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Home',
      ),
    );
    expect(homeWidget.properties.button, isTrue);
    expect(homeWidget.properties.selected, isTrue);
    expect(homeWidget.properties.onTap, isNotNull);

    await tester.tap(find.text('Feeds'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 1);
    final feedsSemantics =
        tester.getSemantics(find.byKey(const ValueKey('app-bottom-tab-1')));
    expect(feedsSemantics.label, 'Feeds');
    final feedsWidget = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Feeds',
      ),
    );
    expect(feedsWidget.properties.button, isTrue);
    expect(feedsWidget.properties.selected, isTrue);
    expect(feedsWidget.properties.onTap, isNotNull);
  });
}
