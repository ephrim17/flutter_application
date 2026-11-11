import 'package:flutter_application/church_app/helpers/event_builders.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/providers/home_sections/promise_provider.dart';
import 'package:flutter_application/church_app/screens/home/sections/events_section.dart';
import 'package:flutter_application/church_app/screens/home/sections/promise_section.dart';
import 'package:flutter_application/church_app/widgets/decorated_scripture_card_widget.dart';
import 'package:flutter_application/church_app/widgets/media_detail_card_widget.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Home's sections have to agree on one left edge.
///
/// Two things can drift apart here, and both have. The Promise Word card is
/// a single card between two carousels and must line up with *their* cards,
/// which sit further in than the carousel itself — a `PageView` below a
/// viewport fraction of 1 insets its page, and the page is then padded by
/// half the carousel spacing.
///
/// A section heading must line up with the card it labels. Events and
/// Announcements used to put their heading outside the centred content
/// column, so on a desktop window the heading stayed pinned near the window
/// edge while its cards centred themselves hundreds of pixels away, and
/// Promise Word put its heading on the column rather than on its card,
/// giving the page three different left edges. These tests pin all of them
/// to one.
///
/// Announcements is deliberately not pumped here: it builds through a
/// private widget and uses the identical composition to Events, so Events
/// is the case under test for that shape.
void main() {
  final event = Event(
    id: 'e1',
    title: 'Sunday Service',
    description: 'Join us for Sunday Service',
    contact: '',
    location: '',
    timing: '7:30 AM',
    startAt: DateTime(2026, 11, 15, 7, 30),
    type: EventType.family,
    isActive: true,
    expiryAt: null,
  );

  Future<void> pumpHome(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          promiseWordProviderLocal.overrideWith(
            (ref) async => {
              'tamil': 'எழும்பிப் பிரகாசி',
              'english': 'Arise, shine',
              'reference': 'Isaiah 60:1',
            },
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: EventsList([event])),
                    ...const PromiseSection().buildSlivers(context),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The heading's text, not the box around it — the box starts at the
  /// column edge and carries the inset as padding.
  Rect headingTextRect(WidgetTester tester, int index) {
    return tester.getRect(
      find
          .descendant(
            of: find.byType(SectionHeader).at(index),
            matching: find.byType(Text),
          )
          .first,
    );
  }

  // 411 is a Pixel; 1280 is a desktop window well past the wide breakpoint,
  // where an uncapped section stretches and the bug was visible.
  for (final width in [411.0, 1280.0]) {
    testWidgets('Promise card lines up with the Events card at $width',
        (tester) async {
      await pumpHome(tester, width);

      final eventCard = tester.getRect(find.byType(MediaDetailCard));
      final promise = tester.getRect(find.byType(DecoratedScriptureCard));

      expect(promise.left, moreOrLessEquals(eventCard.left, epsilon: 0.5));
      expect(promise.right, moreOrLessEquals(eventCard.right, epsilon: 0.5));
    });

    testWidgets('each heading lines up with its own card at $width',
        (tester) async {
      await pumpHome(tester, width);

      final eventCard = tester.getRect(find.byType(MediaDetailCard));
      final promiseCard = tester.getRect(find.byType(DecoratedScriptureCard));

      expect(
        headingTextRect(tester, 0).left,
        moreOrLessEquals(eventCard.left, epsilon: 0.5),
        reason: 'the Events heading should start where its card starts',
      );
      expect(
        headingTextRect(tester, 1).left,
        moreOrLessEquals(promiseCard.left, epsilon: 0.5),
        reason: 'the Promise Word heading should start where its card starts',
      );
    });

    testWidgets('both headings share one left edge at $width', (tester) async {
      await pumpHome(tester, width);

      expect(
        headingTextRect(tester, 0).left,
        moreOrLessEquals(headingTextRect(tester, 1).left, epsilon: 0.5),
      );
    });
  }

  testWidgets('a desktop window centres the content instead of stretching',
      (tester) async {
    await pumpHome(tester, 1280);

    final eventCard = tester.getRect(find.byType(MediaDetailCard));

    // Centred, and nothing like the full 1280.
    expect(eventCard.width, lessThan(700));
    expect(
      eventCard.center.dx,
      moreOrLessEquals(640, epsilon: 0.5),
      reason: 'the card should be centred in the window',
    );
  });
}
