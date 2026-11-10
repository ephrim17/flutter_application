import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/home_sections/promise_provider.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/screens/home/sections/promise_section.dart';
import 'package:flutter_application/church_app/widgets/autoscroll_widget.dart';
import 'package:flutter_application/church_app/widgets/decorated_scripture_card_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Promise Word card is a single card between two carousels (Events,
/// Announcements). Its edges must line up with theirs, not with the section
/// headers, or it reads as wider than everything around it.
void main() {
  Future<void> pumpHome(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 2000);
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
                final screenWidth = MediaQuery.sizeOf(context).width;
                final maxWidth = homeSectionMaxWidth(screenWidth);
                return CustomScrollView(
                  slivers: [
                    // Laid out exactly as EventsList/AnnouncementList do.
                    SliverToBoxAdapter(
                      child: Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxWidth ?? double.infinity,
                          ),
                          child: AutoScrollCarousel(
                            height: 200,
                            itemCount: 1,
                            viewportFraction:
                                homeCarouselViewportFraction(screenWidth),
                            spacing: homeCarouselSpacing,
                            itemBuilder: (_, __) => const SizedBox.expand(
                              key: ValueKey('carousel-card'),
                            ),
                          ),
                        ),
                      ),
                    ),
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

  for (final width in [411.0, 1280.0]) {
    testWidgets('Promise card lines up with carousel cards at $width',
        (tester) async {
      await pumpHome(tester, width);

      final carousel =
          tester.getRect(find.byKey(const ValueKey('carousel-card')));
      final promise = tester.getRect(find.byType(DecoratedScriptureCard));

      expect(promise.left, moreOrLessEquals(carousel.left, epsilon: 0.5));
      expect(promise.right, moreOrLessEquals(carousel.right, epsilon: 0.5));
    });
  }
}
