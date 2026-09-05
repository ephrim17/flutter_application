import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/widgets/app_system_ui_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects contrasting Android system icon brightness', () {
    expect(
      appSystemUiOverlayStyleFor(const Color(0xFFF8F7FF))
          .statusBarIconBrightness,
      Brightness.dark,
    );
    expect(
      appSystemUiOverlayStyleFor(const Color(0xFF101010))
          .statusBarIconBrightness,
      Brightness.light,
    );
  });

  testWidgets('system icons remain visible on light app backgrounds',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFF8F7FF)),
        builder: buildAppSystemUiOverlay,
        home: const Scaffold(),
      ),
    );

    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );

    expect(overlay.value.statusBarIconBrightness, Brightness.dark);
    expect(overlay.value.systemNavigationBarIconBrightness, Brightness.dark);
  });

  testWidgets('system icons remain visible on dark app backgrounds',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF101010),
        ),
        builder: buildAppSystemUiOverlay,
        home: const Scaffold(),
      ),
    );

    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );

    expect(overlay.value.statusBarIconBrightness, Brightness.light);
    expect(overlay.value.systemNavigationBarIconBrightness, Brightness.light);
  });
}
