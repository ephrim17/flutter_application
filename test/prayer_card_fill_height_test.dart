import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/widgets/prayer_request_card.dart';

/// In a rail every card is given the height of the tallest one. Left as it
/// was, the shorter card's footer stayed where its own text ended — so two
/// cards side by side in the same frame had their rule and "days left" line
/// at different heights. `fillHeight` pushes the footer to the card's own
/// bottom edge instead. The Prayer Requests list, where a card is as tall
/// as its content, does not set it and is unaffected.
void main() {
  PrayerRequest prayerWith(String description) => PrayerRequest(
        id: 'p1',
        title: 'Hello World',
        description: description,
        userId: 'u1',
        isAnonymous: true,
        visibleToChurchMembers: true,
        expiryDate: DateTime.now().add(const Duration(days: 1)),
      );

  /// Returns where the card's footer rule landed inside a fixed 400 frame.
  Future<double> footerTop(
    WidgetTester tester, {
    required bool fillHeight,
    String description = 'Pray',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 400,
                child: PrayerRequestCard(
                  prayer: prayerWith(description),
                  fillHeight: fillHeight,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    return tester.getRect(find.byType(Divider)).top;
  }

  testWidgets('without fillHeight the footer sits just under the text',
      (tester) async {
    expect(await footerTop(tester, fillHeight: false), lessThan(300));
  });

  testWidgets('with fillHeight the footer is pushed to the bottom',
      (tester) async {
    expect(await footerTop(tester, fillHeight: true), greaterThan(300));
  });

  testWidgets('and lands in the same place whatever the card says',
      (tester) async {
    final short = await footerTop(tester, fillHeight: true);
    final long = await footerTop(
      tester,
      fillHeight: true,
      description: 'Please pray for my family, for my work, and for the '
          'church — we have a lot going on and could use the support.',
    );

    expect(
      long,
      short,
      reason: 'two cards of the same height must agree on their footer',
    );
  });
}
