import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_count_badge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a compact count and caps very large values',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppCountBadge(count: 42, semanticLabel: 'Members'),
              AppCountBadge(count: 1200),
            ],
          ),
        ),
      ),
    );

    expect(find.text('42'), findsOneWidget);
    expect(find.text('999+'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('42')).label,
      'Members: 42',
    );
  });
}
