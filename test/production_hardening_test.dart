import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/drawer_constants.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/models/user_identity_model.dart';
import 'package:flutter_application/church_app/helpers/event_builders.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invalid remote identity fields fall back without throwing', () {
    final user = UserIdentity.fromFirestore('42', {
      'name': true,
      'email': 'user@example.com',
      'talentsAndGifts': 'not-a-list',
      'dob': 'invalid-date',
    });

    expect(user.uid, '42');
    expect(user.name, 'true');
    expect(user.talentsAndGifts, isEmpty);
    expect(user.dob, isNull);
  });

  test('invalid remote membership fields fall back without throwing', () {
    final member = ChurchMembership.fromFirestore('member-1', 'church-1', {
      'role': '',
      'financialStabilityRating': 'not-a-number',
    });

    expect(member.role, 'user');
    expect(member.financialStabilityRating, 0);
  });

  test('invalid remote theme colors use a safe fallback', () {
    expect('not-a-color'.toColor().toARGB32(), 0xFF000000);
    expect('#112233'.toColor().toARGB32(), 0xFF112233);
  });

  test('events serialize their type as a Firestore-safe string', () {
    final event = Event(
      id: 'event',
      title: 'Title',
      description: 'Description',
      contact: '',
      location: '',
      timing: '',
      type: EventType.youth,
      isActive: true,
      expiryAt: null,
    );

    expect(event.toMap()['type'], 'youth');
  });

  test('financial dashboard stays hidden while the feature is dormant', () {
    final config = AppConfig.fromFirestore({
      'features': {'financialDashboardEnabled': true},
    });

    expect(config.financialDashboardEnabled, isFalse);
    expect(
      DrawerMenuItem.values.map((item) => item.labelKey),
      isNot(contains('drawer.financial_dashboard')),
    );
  });

  test('password reset flow maps server errors to safe user messages', () {
    expect(
      mapFirebaseAuthError(FirebaseAuthException(code: 'invalid-code')),
      'That verification code is incorrect.',
    );
    expect(
      mapFirebaseAuthError(
        FirebaseAuthException(code: 'invalid-reset-session'),
      ),
      'Your password reset session has expired. Please start again.',
    );
  });
}
