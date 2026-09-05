import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared loading indicator renders without animation errors',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AppLoadingIndicator())),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading...'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
