import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/widgets/user_quick_card_widget.dart';

void main() {
  testWidgets('user quick card has one actionable phone icon', (tester) async {
    final user = ChurchMembership.fromFirestore('admin-1', 'church-1', {
      'uid': 'admin-1',
      'displayName': 'Admin User',
      'displayPhone': '8754249990',
      'role': 'admin',
      'approved': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showUserQuickCard(context, user),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final phoneIcon = find.byIcon(Icons.phone_outlined);
    expect(phoneIcon, findsOneWidget);
    expect(find.byIcon(Icons.call_outlined), findsNothing);

    final action = find.ancestor(
      of: phoneIcon,
      matching: find.byType(InkResponse),
    );
    expect(action, findsOneWidget);
    expect(tester.widget<InkResponse>(action).onTap, isNotNull);

    await tester.tap(phoneIcon);
    await tester.pumpAndSettle();

    expect(find.text('Call this number?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('8754249990'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Call this number?'), findsNothing);
  });
}
