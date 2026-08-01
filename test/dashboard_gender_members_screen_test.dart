import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/screens/dashboard/dashboard_gender_members_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gender member page shows all matching members and searches',
      (tester) async {
    final members = [
      AppUser.fromJson({
        'uid': 'male-1',
        'name': 'Arul',
        'email': 'arul@example.com',
        'gender': 'male',
      }),
      AppUser.fromJson({
        'uid': 'female-1',
        'name': 'Beth',
        'email': 'beth@example.com',
        'gender': 'female',
      }),
      AppUser.fromJson({
        'uid': 'male-2',
        'name': 'Daniel',
        'email': 'daniel@example.com',
        'gender': 'Male',
      }),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardGenderMembersScreen(
          gender: 'Male',
          color: Colors.blue,
          members: members,
        ),
      ),
    );

    expect(find.text('Male Members'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);
    expect(find.text('Arul'), findsOneWidget);
    expect(find.text('Daniel'), findsOneWidget);
    expect(find.text('Beth'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'daniel');
    await tester.pump();

    expect(find.text('Arul'), findsNothing);
    expect(find.text('Daniel'), findsOneWidget);
  });
}
