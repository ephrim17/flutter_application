import 'package:firebase_messaging/firebase_messaging.dart';

class FcmNotificationService {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  Future<bool> requestNotificationsPermission() async {
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      criticalAlert: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<String?> getFirebaseMessagingToken() => messaging.getToken();
}
