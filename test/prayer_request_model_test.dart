import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrayerRequest church visibility', () {
    test('is private by default for existing request compatibility', () {
      final prayer = PrayerRequest(
        id: 'prayer-id',
        title: 'Prayer',
        description: 'Please pray',
        userId: 'user-id',
        isAnonymous: false,
        expiryDate: DateTime.utc(2026, 8),
      );

      expect(prayer.visibleToChurchMembers, isFalse);
      expect(prayer.toMap()['visibleToChurchMembers'], isFalse);
    });

    test('persists an explicit church visibility opt-in', () {
      final prayer = PrayerRequest(
        id: 'prayer-id',
        title: 'Prayer',
        description: 'Please pray',
        userId: 'user-id',
        isAnonymous: true,
        visibleToChurchMembers: true,
        expiryDate: DateTime.utc(2026, 8),
      );

      expect(prayer.toMap()['visibleToChurchMembers'], isTrue);
    });
  });

  group('prayer expiry day boundary', () {
    test('tomorrow remains one day away late in the current day', () {
      expect(
        prayerDaysLeft(
          DateTime(2026, 8, 15),
          now: DateTime(2026, 8, 14, 23, 59),
        ),
        1,
      );
    });

    test('selected expiry remains active through that calendar day', () {
      expect(
        prayerDaysLeft(
          DateTime(2026, 8, 15),
          now: DateTime(2026, 8, 15, 23, 59),
        ),
        0,
      );
    });
  });
}
