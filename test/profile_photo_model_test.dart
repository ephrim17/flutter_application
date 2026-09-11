import 'package:flutter_application/church_app/models/church_group_member_model.dart';
import 'package:flutter_application/church_app/models/user_identity_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile photo models', () {
    test('UserIdentity reads, trims, and persists the profile photo URL', () {
      final user = UserIdentity.fromFirestore('user-id', {
        'name': 'Alex Morgan',
        'email': 'alex@example.com',
        'profilePhotoUrl': ' https://example.com/avatar.jpg ',
      });

      expect(user.profilePhotoUrl, 'https://example.com/avatar.jpg');
      expect(
        user.toMap()['profilePhotoUrl'],
        'https://example.com/avatar.jpg',
      );
    });

    test('ChurchGroupMember reads the synchronized profile photo URL', () {
      final member = ChurchGroupMember.fromMap({
        'uid': 'user-id',
        'name': 'Alex Morgan',
        'profilePhotoUrl': 'https://example.com/avatar.jpg',
      });

      expect(member.profilePhotoUrl, 'https://example.com/avatar.jpg');
    });

    test('older records without a profile photo keep an empty fallback', () {
      final user = UserIdentity.fromFirestore('user-id', {
        'name': 'Alex Morgan',
        'email': 'alex@example.com',
      });
      final member =
          ChurchGroupMember.fromMap({'uid': 'user-id', 'name': 'Alex Morgan'});

      expect(user.profilePhotoUrl, isEmpty);
      expect(member.profilePhotoUrl, isEmpty);
    });
  });
}
