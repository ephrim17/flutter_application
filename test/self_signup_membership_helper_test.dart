import 'package:flutter_application/church_app/helpers/self_signup_membership_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deriveSelfSignupCategory', () {
    test('married maps to family', () {
      expect(deriveSelfSignupCategory('Married'), 'family');
    });

    test('anything else maps to individual', () {
      expect(deriveSelfSignupCategory('single'), 'individual');
      expect(deriveSelfSignupCategory(''), 'individual');
    });
  });

  group('resolveSelfSignupFamilyId', () {
    test('slugifies name, category and church into a stable id', () {
      final id = resolveSelfSignupFamilyId(
        category: 'individual',
        name: 'John Doe',
        churchId: 'church_1',
      );
      expect(id, 'individual_john_doe_church_1');
    });

    test('re-normalizing an already-built id is a no-op seed-wise', () {
      final first = resolveSelfSignupFamilyId(
        category: 'family',
        name: 'Mary Ann',
        churchId: 'church_1',
      );
      final reNormalizedSeed = normalizeMembershipSeed(first, 'church_1');
      expect(reNormalizedSeed, 'mary_ann');
    });

    test('empty name or category yields empty id', () {
      expect(
        resolveSelfSignupFamilyId(category: '', name: 'X', churchId: 'c'),
        '',
      );
      expect(
        resolveSelfSignupFamilyId(category: 'individual', name: '', churchId: 'c'),
        '',
      );
    });
  });
}
