import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
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

const AndroidNotificationChannel _churchMessageChannel =
    AndroidNotificationChannel(
  'church_messages',
  'Church Messages',
  description: 'Push notifications for church updates and activity',
  importance: Importance.max,
);

bool _notificationPresentationInitialized = false;
bool _notificationListenersAttached = false;
bool _notificationInitialMessageHandled = false;

Future<void> initializeNotificationPresentation() async {
  if (_notificationPresentationInitialized || kIsWeb) {
    return;
  }

  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await _localNotifications.initialize(settings);

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
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await showRemoteMessageNotification(message);
}

Future<void> handleNotificationSetup({
  required BuildContext context,
  required WidgetRef ref,
  bool promptIfNeeded = true,
}) async {
  if (kIsWeb) {
    return;
  }

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

    await _syncNotificationState(ref);
    await _attachNotificationListeners(messaging);
  } catch (e) {
    debugPrint("Notification setup error: $e");
  }
}

Future<void> syncNotificationTopicIfAuthorized(WidgetRef ref) async {
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

    await _syncNotificationState(ref);
    await _attachNotificationListeners(messaging);
  } catch (e) {
    debugPrint("Notification topic sync error: $e");
  }
}

Future<void> _syncNotificationState(WidgetRef ref) async {
  final messaging = FirebaseMessaging.instance;
  final token = await messaging.getToken();
  if (token == null) return;

  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) return;

  final churchId = await ref.read(currentChurchIdProvider.future);
  if (churchId == null) return;
  final churchTopic = 'church_$churchId';

  final repo = ChurchUsersRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );
  final localStorage = ChurchLocalStorage();

  final existingToken = await repo.getExistingAuthToken(firebaseUser.uid);

  if (existingToken != token) {
    await repo.updateAuthToken(
      uid: firebaseUser.uid,
      token: token,
    );
  }

  final previousTopic = await localStorage.getSubscribedChurchTopic();
  if (previousTopic != null &&
      previousTopic.isNotEmpty &&
      previousTopic != churchTopic) {
    await messaging.unsubscribeFromTopic(previousTopic);
  }

  if (previousTopic != churchTopic) {
    await messaging.subscribeToTopic(churchTopic);
    await localStorage.saveSubscribedChurchTopic(churchTopic);
  }

  FirebaseMessaging.instance.onTokenRefresh.listen(
    (newToken) async {
      await repo.updateAuthToken(
        uid: firebaseUser.uid,
        token: newToken,
      );
      await messaging.subscribeToTopic(churchTopic);
    },
  );
}

Future<void> _attachNotificationListeners(FirebaseMessaging messaging) async {
  if (_notificationListenersAttached) {
    return;
  }

  FirebaseMessaging.onMessage.listen(showRemoteMessageNotification);
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    debugPrint(
      'Notification opened: ${message.messageId ?? 'unknown-message'}',
    );
  });

  if (!_notificationInitialMessageHandled) {
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        'Notification opened from terminated state: '
        '${initialMessage.messageId ?? 'unknown-message'}',
      );
    }
    _notificationInitialMessageHandled = true;
  }

  _notificationListenersAttached = true;
}
