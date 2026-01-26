

import 'package:firebase_messaging/firebase_messaging.dart';

class FcmNotificationService {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  void requestNotificationsPermission() async{
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      criticalAlert: true,
      sound: true
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission'); //FOR IOS
    } else {
      print('User declined or has not accepted permission');
    }
  }

  Future<String> getFirebaseMessagingToken() async {
    String? token = await messaging.getToken();
    return token!;
  }
}