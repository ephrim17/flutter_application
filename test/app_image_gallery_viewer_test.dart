import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/widgets/app_image_gallery_viewer.dart';

/// The full-screen viewer has to behave like a phone's photo viewer: a photo
/// that fits the screen does not move at all, and only once it is magnified
/// can it be panned — never loose inside the black backdrop.
///
/// The image never resolves under test (HTTP is stubbed out), so its
/// placeholder spinner animates forever and `pumpAndSettle` would time out.
/// Every wait here is a fixed `pump`.
Widget _viewer(List<String> urls) => ProviderScope(
      child: MaterialApp(
        home: AppImageGalleryViewer(imageUrls: urls),
      ),
    );

/// The live transform InteractiveViewer is applying to its child.
Matrix4 _transform(WidgetTester tester) {
  return tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(InteractiveViewer),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform;
}

Future<void> _doubleTapAt(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('a fitted photo cannot be dragged around', (tester) async {
    await tester.pumpWidget(_viewer(const ['https://example.com/a.jpg']));
    await tester.pump();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    // A boundary margin is slack around the child; any non-zero value lets
    // the photo be dragged off-centre at fit scale.
    expect(viewer.boundaryMargin, EdgeInsets.zero);
    expect(viewer.minScale, 1);

    await tester.drag(find.byType(InteractiveViewer), const Offset(-120, -90));
    await tester.pump(const Duration(milliseconds: 400));

    expect(_transform(tester), Matrix4.identity());
  });

  testWidgets('a zoomed photo can be panned', (tester) async {
    await tester.pumpWidget(_viewer(const ['https://example.com/a.jpg']));
    await tester.pump();

    await _doubleTapAt(tester, tester.getCenter(find.byType(InteractiveViewer)));
    expect(_transform(tester).getMaxScaleOnAxis(), greaterThan(1));

    final before = _transform(tester).getTranslation();
    await tester.drag(find.byType(InteractiveViewer), const Offset(-60, 0));
    await tester.pump(const Duration(milliseconds: 400));

    expect(_transform(tester).getTranslation(), isNot(before));
  });

  testWidgets('swiping between photos is blocked while one is zoomed',
      (tester) async {
    await tester.pumpWidget(
      _viewer(const [
        'https://example.com/a.jpg',
        'https://example.com/b.jpg',
      ]),
    );
    await tester.pump();

    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isA<PageScrollPhysics>(),
    );

    await _doubleTapAt(
      tester,
      tester.getCenter(find.byType(InteractiveViewer).first),
    );

    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isA<NeverScrollableScrollPhysics>(),
      reason: 'a horizontal drag must pan the zoomed photo, not page away',
    );
  });

  testWidgets('double-tap near a corner never exposes empty space',
      (tester) async {
    await tester.pumpWidget(_viewer(const ['https://example.com/a.jpg']));
    await tester.pump();

    final rect = tester.getRect(find.byType(InteractiveViewer));
    // The naive translation for a corner tap lands outside the image, which
    // would show black down one edge; it has to be clamped.
    await _doubleTapAt(tester, Offset(rect.right - 2, rect.bottom - 2));

    final matrix = _transform(tester);
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    expect(scale, greaterThan(1));
    expect(translation.x, lessThanOrEqualTo(0.001));
    expect(translation.y, lessThanOrEqualTo(0.001));
    expect(translation.x, greaterThanOrEqualTo(-rect.width * (scale - 1) - 1));
    expect(translation.y, greaterThanOrEqualTo(-rect.height * (scale - 1) - 1));
  });
}
