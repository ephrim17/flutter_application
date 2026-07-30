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
}
