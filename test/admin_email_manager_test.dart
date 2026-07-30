import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/admin_email_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin manager adds, edits, and removes individual emails',
      (tester) async {
    var savedAdmins = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminEmailManager(
            initialAdmins: const [
              'first@example.com',
              'second@example.com',
            ],
            onSave: (admins) async => savedAdmins = List<String>.from(admins),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField),
      'third@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('admin-email-submit')));
    await tester.pumpAndSettle();

    expect(savedAdmins, contains('third@example.com'));
    expect(find.text('third@example.com'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit admin').first);
    await tester.pump();
    await tester.enterText(
      find.byType(TextFormField),
      'updated@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('admin-email-submit')));
    await tester.pumpAndSettle();

    expect(savedAdmins, contains('updated@example.com'));
    expect(savedAdmins, isNot(contains('first@example.com')));

    await tester.tap(find.byTooltip('Remove admin').last);
    await tester.pumpAndSettle();
    expect(find.text('Remove administrator?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(savedAdmins, isNot(contains('third@example.com')));
    expect(find.text('third@example.com'), findsNothing);
  });

  testWidgets('admin manager validates duplicates and keeps a final admin',
      (tester) async {
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminEmailManager(
            initialAdmins: const ['only@example.com'],
            onSave: (_) async => saveCalls++,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'only@example.com');
    await tester.tap(find.byKey(const ValueKey('admin-email-submit')));
    await tester.pump();
    expect(find.text('This admin is already in the list.'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove admin'));
    await tester.pump();
    expect(
      find.text('Add another admin before removing the last administrator.'),
      findsOneWidget,
    );
    expect(saveCalls, 0);
  });
}
