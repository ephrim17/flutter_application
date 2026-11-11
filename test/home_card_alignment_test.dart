import 'package:flutter_application/church_app/helpers/event_builders.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_card_layout.dart';
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

  testWidgets('the gutter is a flat 16 at every width, as For You is',
      (tester) async {
    // A gutter that is a share of the screen looks right on a phone and
    // becomes a wide empty margin on a desktop window. Tying the expected
    // value to `forYouSidePadding` is the point: the two tabs have to agree,
    // so if one moves this fails rather than drifting quietly.
    for (final width in [320.0, 411.0, 768.0, 1280.0, 1920.0]) {
      await pumpHome(tester, width);

      for (final rect in [
        tester.getRect(find.byType(MediaDetailCard)),
        tester.getRect(find.byType(DecoratedScriptureCard)),
      ]) {
        expect(
          rect.left,
          moreOrLessEquals(forYouSidePadding, epsilon: 0.5),
          reason: 'left gutter at $width',
        );
        expect(
          rect.right,
          moreOrLessEquals(width - forYouSidePadding, epsilon: 0.5),
          reason: 'right gutter at $width',
        );
      }
    }
  });

  testWidgets('cards grow with the window rather than capping', (tester) async {
    // Home has no maximum width: a card takes the screen it is given, the
    // way For You's cards always have. A fixed cap here would centre a
    // narrow column in a wide browser window and leave the rest empty.
    await pumpHome(tester, 1280);
    final wide = tester.getRect(find.byType(MediaDetailCard));

    await pumpHome(tester, 411);
    final narrow = tester.getRect(find.byType(MediaDetailCard));

    expect(
      wide.width,
      greaterThan(narrow.width * 2),
      reason: 'a card should scale with the window, not sit at a fixed width',
    );
    expect(
      wide.width,
      greaterThan(1100),
      reason: 'a 1280 window should give a card most of its width',
    );
  });

  testWidgets('no section overflows its screen at any width', (tester) async {
    for (final width in [320.0, 411.0, 768.0, 1280.0, 1920.0]) {
      await pumpHome(tester, width);

      expect(
        tester.takeException(),
        isNull,
        reason: 'Home overflowed at $width',
      );

      for (final rect in [
        tester.getRect(find.byType(MediaDetailCard)),
        tester.getRect(find.byType(DecoratedScriptureCard)),
      ]) {
        expect(rect.left, greaterThanOrEqualTo(-0.5), reason: 'at $width');
        expect(rect.right, lessThanOrEqualTo(width + 0.5), reason: 'at $width');
      }
    }
  });
}
