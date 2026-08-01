import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';

void main() {
  testWidgets('shared modal renders exactly one drag handle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppModalBottomSheet<void>(
                context: context,
                builder: (_) => const Center(child: Text('Modal content')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('app-modal-drag-handle')),
      findsOneWidget,
    );
  });

  testWidgets('shared modal stays above the software keyboard', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppModalBottomSheet<void>(
                context: context,
                builder: (_) => const ColoredBox(
                  key: ValueKey<String>('keyboard-safe-content'),
                  color: Colors.white,
                ),
              ),
              child: const Text('Open keyboard modal'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open keyboard modal'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final contentBottom = tester
        .getBottomRight(find.byKey(
          const ValueKey<String>('keyboard-safe-content'),
        ))
        .dy;
    expect(contentBottom, lessThanOrEqualTo(500));
    expect(tester.takeException(), isNull);
  });
}
