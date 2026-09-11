import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/screens/dashboard/dashboard_gender_members_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gender member page shows all matching members and searches',
      (tester) async {
    final members = [
      ChurchMembership.fromFirestore('male-1', 'church-1', {
        'uid': 'male-1',
        'displayName': 'Arul',
        'displayEmail': 'arul@example.com',
        'displayGender': 'male',
      }),
      ChurchMembership.fromFirestore('female-1', 'church-1', {
        'uid': 'female-1',
        'displayName': 'Beth',
        'displayEmail': 'beth@example.com',
        'displayGender': 'female',
      }),
      ChurchMembership.fromFirestore('male-2', 'church-1', {
        'uid': 'male-2',
        'displayName': 'Daniel',
        'displayEmail': 'daniel@example.com',
        'displayGender': 'Male',
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
