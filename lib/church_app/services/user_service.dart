import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/notification_reprompt_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> handleNotificationSetup({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final messaging = FirebaseMessaging.instance;

  try {
    /// 1️⃣ Check current permission status
    NotificationSettings settings =
        await messaging.getNotificationSettings();

    bool isAuthorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    /// 2️⃣ If NOT authorized → show your custom sheet first
    if (!isAuthorized) {
      final shouldRequest =
          await showNotificationPermissionSheet(context);

      if (shouldRequest != true) return;

      /// Request system permission
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

    /// 3️⃣ Get FCM token
    final token = await messaging.getToken();
    if (token == null) return;

    print("<<< FCM Token: $token");

    /// 4️⃣ Get current user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    /// 5️⃣ Get existing token
    final snapshot = await userDoc.get();
    final existingToken = snapshot.data()?['authToken'];

    /// 6️⃣ Update ONLY if changed
    if (existingToken != token) {
      await userDoc.set({
        'authToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    /// 7️⃣ Listen to token refresh (attach once)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await userDoc.set({
        'authToken': newToken,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

  } catch (e) {
    debugPrint("Notification setup error: $e");
  }
}

  final userNameProvider =
    FutureProvider.family<String?, String>((ref, uid) async {
  final firestore = FirebaseFirestore.instance;

  try {
    final doc =
        await firestore.collection('users').doc(uid).get();

    if (!doc.exists) return null;

    return doc.data()?['name'] as String?;
  } catch (_) {
    return null;
  }
});