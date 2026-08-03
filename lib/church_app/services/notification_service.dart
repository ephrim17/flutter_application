import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/models/text_content_defaults.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/church_user_repository.dart';
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
  if (kIsWeb) {
    return;
  }

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
  if (kIsWeb) {
    return;
  }

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

Future<void> _syncNotificationState(ProviderContainer container) async {
  final messaging = FirebaseMessaging.instance;
  final token = await messaging.getToken();
  if (token == null) return;

  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) return;

  final churchId = await container.read(currentChurchIdProvider.future);
  if (churchId == null) return;
  final churchTopic = 'church_$churchId';

  final repo = ChurchUsersRepository(
    firestore: container.read(firestoreProvider),
    churchId: churchId,
  );
  final localStorage = ChurchLocalStorage();
  final userSnapshot = await repo.userDoc(firebaseUser.uid).get();
  final appUser = userSnapshot.data();
  if (appUser == null) return;

  final existingToken = await repo.getExistingAuthToken(firebaseUser.uid);

  if (existingToken != token) {
    await repo.updateAuthToken(
      uid: firebaseUser.uid,
      token: token,
    );
  }

  final desiredTopics = <String>{
    churchTopic,
    _churchUserTopic(churchId, firebaseUser.uid),
    ...appUser.churchGroupIds.map(
      (groupId) => _churchGroupTopic(churchId, groupId),
    ),
  };
  final previousTopics = await localStorage.getSubscribedNotificationTopics();

  await Future.wait(
    previousTopics
        .difference(desiredTopics)
        .map(messaging.unsubscribeFromTopic),
  );
  await Future.wait(
    desiredTopics.difference(previousTopics).map(messaging.subscribeToTopic),
  );
  await localStorage.saveSubscribedNotificationTopics(desiredTopics);

  await _tokenRefreshSubscription?.cancel();
  _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
    (newToken) async {
      await repo.updateAuthToken(
        uid: firebaseUser.uid,
        token: newToken,
      );
      await Future.wait(desiredTopics.map(messaging.subscribeToTopic));
    },
  );
}

String _churchGroupTopic(String churchId, String groupId) =>
    'church_${_notificationTopicSegment(churchId)}_group_'
    '${_notificationTopicSegment(groupId)}';

String _churchUserTopic(String churchId, String uid) =>
    'church_${_notificationTopicSegment(churchId)}_user_'
    '${_notificationTopicSegment(uid)}';

String _notificationTopicSegment(String value) =>
    value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\-_.~%]'), '_');

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

void _handleNotificationNavigation(RemoteMessage message) {
  _handleNotificationKind(message.data['kind']?.toString());
}

void _handleNotificationKind(String? kind) {
  switch (kind) {
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
