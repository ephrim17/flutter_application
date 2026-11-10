import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';

/// Notifications are addressed to people rather than to the church they
/// happen to have open, so a member of several churches hears from all of
/// them. That makes the payload's `churchId` load-bearing: without it a
/// church-B prayer request opens church A's Pray For Others screen — the
/// right screen, the wrong church's data.
///
/// Delivery itself cannot be covered here. A real push needs a device with
/// working Play Services, which a plain emulator image does not have, so what
/// is pinned is the decision the app makes once a payload arrives.
void main() {
  setUp(() {
    notificationChurchRequest.value = null;
    notificationTabRequest.value = null;
    notificationDestinationRequest.value = null;
  });

  group('church routing', () {
    test('a payload names the church it came from', () {
      applyNotificationPayload({
        'kind': 'feed_post_created',
        'churchId': 'yesu_thottam_prayer_house',
      });
      expect(notificationChurchRequest.value, 'yesu_thottam_prayer_house');
    });

    test('asks for no church when the payload carries none', () {
      applyNotificationPayload({'kind': 'live_church'});
      expect(notificationChurchRequest.value, isNull);
    });

    test('a blank or whitespace churchId is treated as none', () {
      applyNotificationPayload({'kind': 'live_church', 'churchId': '   '});
      expect(notificationChurchRequest.value, isNull);
    });

    test('the request survives a kind the app does not route', () {
      // The church still has to be switched even when there is nowhere
      // specific to land, or the user is left in the wrong church entirely.
      applyNotificationPayload({'kind': 'something_new', 'churchId': 'tnbm'});
      expect(notificationChurchRequest.value, 'tnbm');
      expect(notificationTabRequest.value, isNull);
      expect(notificationDestinationRequest.value, isNull);
    });
  });

  group('destination routing', () {
    test('a feed post opens the Community tab', () {
      applyNotificationPayload({
        'kind': 'feed_post_created',
        'churchId': 'tnbm',
      });
      expect(notificationTabRequest.value, 2);
    });

    test('live church opens the For You tab', () {
      applyNotificationPayload({'kind': 'live_church', 'churchId': 'tnbm'});
      expect(notificationTabRequest.value, 1);
    });

    test('articles route to the articles destination', () {
      applyNotificationPayload({'kind': 'article_created', 'churchId': 'tnbm'});
      expect(
        notificationDestinationRequest.value,
        NotificationDestination.articles,
      );
    });

    test('both prayer kinds route to Pray For Others', () {
      for (final kind in ['prayer_request_created', 'prayer_request_visible']) {
        notificationDestinationRequest.value = null;
        applyNotificationPayload({'kind': kind, 'churchId': 'tnbm'});
        expect(
          notificationDestinationRequest.value,
          NotificationDestination.prayForOthers,
          reason: kind,
        );
      }
    });

    test('faith kinds route to faith engagement', () {
      for (final kind in ['faith_engagement', 'faith_daily_loop']) {
        notificationDestinationRequest.value = null;
        applyNotificationPayload({'kind': kind, 'churchId': 'tnbm'});
        expect(
          notificationDestinationRequest.value,
          NotificationDestination.faithEngagement,
          reason: kind,
        );
      }
    });

    test('circle kinds route to circles', () {
      for (final kind in ['faith_circles', 'circle_response_created']) {
        notificationDestinationRequest.value = null;
        applyNotificationPayload({'kind': kind, 'churchId': 'tnbm'});
        expect(
          notificationDestinationRequest.value,
          NotificationDestination.circles,
          reason: kind,
        );
      }
    });
  });

  group('cross-church scenarios', () {
    test('church B while church A is open asks for B', () {
      applyNotificationPayload({
        'kind': 'prayer_request_visible',
        'churchId': 'church_b',
      });
      // The shell compares this against the selected church and switches
      // before honouring the destination.
      expect(notificationChurchRequest.value, 'church_b');
      expect(
        notificationDestinationRequest.value,
        NotificationDestination.prayForOthers,
      );
    });

    test('a second notification replaces the first church request', () {
      applyNotificationPayload({'kind': 'live_church', 'churchId': 'first'});
      applyNotificationPayload({'kind': 'live_church', 'churchId': 'second'});
      expect(notificationChurchRequest.value, 'second');
    });
  });
}
