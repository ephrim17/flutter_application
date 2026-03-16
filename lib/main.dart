import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/prayer_notification_service.dart';
import 'package:flutter_application/church_app/screens/entry/app_bootstrap.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_application/firebase_options.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform
//   );
//   runApp(ProviderScope(child: const AppStarterMenu()));
// }

/* church App */
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrayerNotificationService.instance.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeNotificationPresentation();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  if (kDebugMode) {
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  }
  runApp(ProviderScope(child: AppBootstrap()));
}
