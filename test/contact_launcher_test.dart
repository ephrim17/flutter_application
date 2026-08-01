import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/contact_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes phone, email, and common map links', () {
    expect(
      externalActionTypeForUri(Uri.parse('tel:8754249990')),
      ExternalActionType.phone,
    );
    expect(
      externalActionTypeForUri(Uri.parse('mailto:hello@example.com')),
      ExternalActionType.email,
    );
    expect(
      externalActionTypeForUri(
        Uri.parse('https://www.google.com/maps/search/?query=Chennai'),
      ),
      ExternalActionType.map,
    );
    expect(
      externalActionTypeForUri(Uri.parse('https://maps.app.goo.gl/example')),
      ExternalActionType.map,
    );
    expect(
      externalActionTypeForUri(Uri.parse('https://example.com')),
      ExternalActionType.other,
    );
  });

  testWidgets('email launch asks before opening another app', (tester) async {
    await _pumpLauncher(
      tester,
      Uri.parse('mailto:hello@example.com'),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Open your email app?'), findsOneWidget);
    expect(find.text('hello@example.com'), findsOneWidget);
    expect(find.text('Open email'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Open your email app?'), findsNothing);
  });

  testWidgets('map launch asks before opening another app', (tester) async {
    await _pumpLauncher(
      tester,
      Uri.parse('https://www.google.com/maps/search/?api=1&query=Chennai'),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Open this location?'), findsOneWidget);
    expect(find.text('Chennai'), findsOneWidget);
    expect(find.text('Open maps'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Open this location?'), findsNothing);
  });
}

Future<void> _pumpLauncher(WidgetTester tester, Uri uri) {
  return tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => launchExternalUri(context, uri),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}
