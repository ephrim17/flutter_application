import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/helpers/feed_reaction_summary.dart';
import 'package:flutter_application/church_app/widgets/feed_reaction_summary_pill.dart';

/// Before this pill existed, the only way into a post's reactor list was a
/// long-press on the small corner reaction button — undiscoverable, and
/// silently a no-op for anyone who wasn't the author or a church admin. The
/// pill is now the affordance, so what it shows and that it is tappable are
/// the things worth pinning.
Future<void> _pump(
  WidgetTester tester,
  Map<String, int> summary, {
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: FeedReactionSummaryPill(
            summary: summary,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the emoji used and the total', (tester) async {
    await _pump(tester, const {'🙏': 4, '❤️': 2});

    expect(find.text('🙏'), findsOneWidget);
    expect(find.text('❤️'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('a post with no reactions shows no pill at all', (tester) async {
    await _pump(tester, const {});

    // Not a "0" pill sitting on every quiet post — nothing.
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('a reaction count of zero is treated as no reactions',
      (tester) async {
    // A stale aggregate can hold an emoji at zero after the last reactor
    // removed theirs.
    await _pump(tester, const {'👍': 0});

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('tapping it opens the reactor list', (tester) async {
    var taps = 0;
    await _pump(tester, const {'🙏': 3}, onTap: () => taps++);

    await tester.tap(find.byType(FeedReactionSummaryPill));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('a busy post shows a capped set of emoji, full total',
      (tester) async {
    await _pump(tester, const {'🙏': 9, '❤️': 8, '🤍': 7, '👍': 6, '🎉': 5});

    expect(find.text('35'), findsOneWidget);
    expect(find.text('🙏'), findsOneWidget);
    expect(find.text('❤️'), findsOneWidget);
    expect(find.text('🤍'), findsOneWidget);
    // Beyond the cap the pill would outgrow the card's corner.
    expect(find.text('👍'), findsNothing);
    expect(find.text('🎉'), findsNothing);
    expect(feedReactionPillMaxEmoji, 3);
  });

  testWidgets('carries a screen-reader label, not a bare number',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const {'🙏': 3});

    expect(
      find.bySemanticsLabel('3 reactions. See who reacted.'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
