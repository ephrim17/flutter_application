import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/device_installation_id.dart';
import 'package:flutter_application/church_app/models/text_content_defaults.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/user_identity_repository.dart';
import 'package:flutter_application/church_app/widgets/notification_reprompt_sheet.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application/firebase_options.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

final AndroidNotificationChannel _churchMessageChannel =
    AndroidNotificationChannel(
  'church_messages',
  defaultChurchTextContents['notifications.channel_name']!,
  description: defaultChurchTextContents['notifications.channel_description'],
  importance: Importance.max,
);

bool _notificationPresentationInitialized = false;
bool _notificationListenersAttached = false;
bool _notificationInitialMessageHandled = false;
Future<void>? _activeNotificationSetup;
StreamSubscription<String>? _tokenRefreshSubscription;
final ValueNotifier<int?> notificationTabRequest = ValueNotifier<int?>(null);
final ValueNotifier<NotificationDestination?> notificationDestinationRequest =
    ValueNotifier<NotificationDestination?>(null);

enum NotificationDestination {
  articles,
  prayForOthers,
  faithEngagement,
  circles,
}

Future<void> initializeNotificationPresentation() async {
  if (_notificationPresentationInitialized || kIsWeb) {
    return;
  }

  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await _localNotifications.initialize(
    settings,
    onDidReceiveNotificationResponse: (response) {
      _handleNotificationKind(response.payload);
    },
  );

  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_churchMessageChannel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  _notificationPresentationInitialized = true;
}

Future<void> showRemoteMessageNotification(RemoteMessage message) async {
  // Web shows nothing from here on purpose. While the tab is closed or in
  // the background the service worker displays the push itself; while it is
  // focused the SDK hands the message to `onMessage` and deliberately does
  // not display it, because the person is already looking at the app. Using
  // the Notification API here as well would double up the background case.
  if (kIsWeb) {
    return;
  }

  await initializeNotificationPresentation();

  final notification = message.notification;
  final title = notification?.title ?? message.data['title']?.toString();
  final body = notification?.body ?? message.data['body']?.toString();

  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
    return;
  }

  await _localNotifications.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _churchMessageChannel.id,
        _churchMessageChannel.name,
        channelDescription: _churchMessageChannel.description,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    payload: message.data['kind']?.toString(),
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await showRemoteMessageNotification(message);
}

Future<void> handleNotificationSetup({
  required BuildContext context,
  required ProviderContainer container,
  bool promptIfNeeded = true,
}) async {
  final activeSetup = _activeNotificationSetup;
  if (activeSetup != null) {
    return activeSetup;
  }

  final setup = _runNotificationSetup(
    context: context,
    container: container,
    promptIfNeeded: promptIfNeeded,
  );
  _activeNotificationSetup = setup.whenComplete(() {
    _activeNotificationSetup = null;
  });
  return _activeNotificationSetup!;
}

Future<void> _runNotificationSetup({
  required BuildContext context,
  required ProviderContainer container,
  required bool promptIfNeeded,
}) async {
  final messaging = FirebaseMessaging.instance;

  try {
    await initializeNotificationPresentation();

    /// 1️⃣ Check permission
    NotificationSettings settings = await messaging.getNotificationSettings();

    bool isAuthorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    /// 2️⃣ Show custom sheet if needed
    if (!isAuthorized) {
      if (!promptIfNeeded) return;

      if (!context.mounted) return;
      final shouldRequest = await showNotificationPermissionSheet(context);
      if (!context.mounted) return;

      if (shouldRequest != true) return;

      settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!isAuthorized) return;
    }

    await _syncNotificationState(container);
    await _attachNotificationListeners(messaging);
  } catch (e) {
    debugPrint("Notification setup error: $e");
  }
}

Future<void> syncNotificationTopicIfAuthorized(
  ProviderContainer container,
) async {
  final messaging = FirebaseMessaging.instance;

  try {
    await initializeNotificationPresentation();

    final settings = await messaging.getNotificationSettings();
    final isAuthorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!isAuthorized) return;

    await _syncNotificationState(container);
    await _attachNotificationListeners(messaging);
  } catch (e) {
    debugPrint("Notification topic sync error: $e");
  }
}

/// What the device registry records this device as.
///
/// `defaultTargetPlatform` on the web reports the host operating system, so
/// a browser on a Mac registered itself as "macOS" and the registry could
/// not tell a web session from the desktop app it does not have.
String get _devicePlatformName => kIsWeb ? 'web' : defaultTargetPlatform.name;

/// The project's Web Push certificate (Firebase console → Project settings →
/// Cloud Messaging → Web configuration), if one has been generated.
///
/// Left null deliberately: with no key the JS SDK falls back to Firebase's
/// own default application server key, which is what makes web push work
/// without a trip to the console. Set this to the project's own key to stop
/// relying on that default — tokens issued under the old key stop working
/// when it changes, so expect existing web devices to re-register.
const String? webPushVapidKey = null;

Future<void> _syncNotificationState(ProviderContainer container) async {
  final messaging = FirebaseMessaging.instance;
  final token = await messaging.getToken(
    vapidKey: kIsWeb ? webPushVapidKey : null,
  );
  if (token == null) return;

  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) return;

  final firestore = container.read(firestoreProvider);
  final identityRepo = UserIdentityRepository(firestore: firestore);
  final installationId = await getDeviceInstallationId();

  // Written every launch regardless of selected church (§4.1, Phase 5) —
  // this is what lets notifications for OTHER churches reach a device that
  // last opened a different one (§2.6), and what lets a guest-shell user
  // (no approved membership yet, so no selected church at all) still be
  // reachable. Must happen before the churchId check below, not after —
  // this used to be gated on having a church selected, which meant it
  // silently never ran at all for that case.
  await identityRepo.registerDevice(
    uid: firebaseUser.uid,
    installationId: installationId,
    fcmToken: token,
    platform: _devicePlatformName,
  );

  await _tokenRefreshSubscription?.cancel();
  _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
    (newToken) async {
      // Re-register and stop. There are no topic subscriptions to repair:
      // the server resolves who to notify from church membership at send
      // time, so a device is reachable the moment its token is on record.
      await identityRepo.registerDevice(
        uid: firebaseUser.uid,
        installationId: installationId,
        fcmToken: newToken,
        platform: _devicePlatformName,
      );
    },
  );
}

Future<void> _attachNotificationListeners(FirebaseMessaging messaging) async {
  if (_notificationListenersAttached) {
    return;
  }

  FirebaseMessaging.onMessage.listen(showRemoteMessageNotification);
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    _handleNotificationNavigation(message);
    debugPrint(
      'Notification opened: ${message.messageId ?? 'unknown-message'}',
    );
  });

  if (!_notificationInitialMessageHandled) {
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage);
      debugPrint(
        'Notification opened from terminated state: '
        '${initialMessage.messageId ?? 'unknown-message'}',
      );
    }
    _notificationInitialMessageHandled = true;
  }

  _notificationListenersAttached = true;
}

/// The church a tapped notification belongs to, when it is not the one the
/// app currently has open.
///
/// Notifications are addressed to people, not to the church they happen to
/// have selected, so a member of several churches is told about all of them.
/// That makes the payload's `churchId` load-bearing: routing a church-B
/// prayer request to the Pray For Others screen while church A is open shows
/// the wrong church's data. [ChurchTabScreen] switches church on this before
/// honouring the destination below.
final ValueNotifier<String?> notificationChurchRequest =
    ValueNotifier<String?>(null);

void _handleNotificationNavigation(RemoteMessage message) {
  applyNotificationPayload(message.data);
}

/// Turns a tapped notification's data payload into the two requests the app
/// shell acts on: which church it belongs to, and where inside that church it
/// points.
///
/// Split out from [_handleNotificationNavigation] so the routing table can be
/// exercised without a live push — FCM delivery needs a device with working
/// Play Services, which rules out testing this on a plain emulator image.
@visibleForTesting
void applyNotificationPayload(Map<String, dynamic> data) {
  final churchId = data['churchId']?.toString().trim() ?? '';
  if (churchId.isNotEmpty) notificationChurchRequest.value = churchId;
  _handleNotificationKind(data['kind']?.toString());
}

void _handleNotificationKind(String? kind) {
  switch (kind) {
    // Tab 2 while the Community feed existed. That tab is commented out of
    // `ChurchTabScreen`, so 2 is now Messages for an admin and out of range
    // for an ordinary member — the feed itself is not reachable from
    // anywhere. Home is the honest destination until Community returns, at
    // which point this goes back to the feed's index.
    case 'feed_post_created':
      notificationTabRequest.value = 0;
    case 'live_church':
      notificationTabRequest.value = 1;
    case 'article_created':
      notificationDestinationRequest.value = NotificationDestination.articles;
    case 'prayer_request_created':
    case 'prayer_request_visible':
      notificationDestinationRequest.value =
          NotificationDestination.prayForOthers;
    case 'faith_engagement':
    case 'faith_daily_loop':
      notificationDestinationRequest.value =
          NotificationDestination.faithEngagement;
    case 'faith_circles':
    case 'circle_response_created':
      notificationDestinationRequest.value = NotificationDestination.circles;
  }
}
