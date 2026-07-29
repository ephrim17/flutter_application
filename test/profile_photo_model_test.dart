import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/church_group_member_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile photo models', () {
    test('AppUser reads, trims, and persists the profile photo URL', () {
      final user = AppUser.fromJson({
        'uid': 'user-id',
        'name': 'Alex Morgan',
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
      final user = AppUser.fromJson({'uid': 'user-id', 'name': 'Alex Morgan'});
      final member =
          ChurchGroupMember.fromMap({'uid': 'user-id', 'name': 'Alex Morgan'});

      expect(user.profilePhotoUrl, isEmpty);
      expect(member.profilePhotoUrl, isEmpty);
    });
  });
}
