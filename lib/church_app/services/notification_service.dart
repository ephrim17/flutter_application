import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/church_user_repository.dart';
import 'package:flutter_application/church_app/widgets/notification_reprompt_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> handleNotificationSetup({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final messaging = FirebaseMessaging.instance;

  try {
    /// 1️⃣ Check permission
    NotificationSettings settings =
        await messaging.getNotificationSettings();

    bool isAuthorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    /// 2️⃣ Show custom sheet if needed
    if (!isAuthorized) {
      final shouldRequest =
          await showNotificationPermissionSheet(context);

      if (shouldRequest != true) return;

      settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      isAuthorized =
          settings.authorizationStatus ==
                  AuthorizationStatus.authorized ||
              settings.authorizationStatus ==
                  AuthorizationStatus.provisional;

      if (!isAuthorized) return;
    }

    /// 3️⃣ Get FCM token
    final token = await messaging.getToken();
    if (token == null) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final churchId =
        await ref.read(currentChurchIdProvider.future);
    if (churchId == null) return;

    final repo = ChurchUsersRepository(
      firestore: ref.read(firestoreProvider),
      churchId: churchId,
    );

    /// 4️⃣ Update only if changed
    final existingToken =
        await repo.getExistingAuthToken(firebaseUser.uid);

    if (existingToken != token) {
      await repo.updateAuthToken(
        uid: firebaseUser.uid,
        token: token,
      );
    }

    /// 5️⃣ Listen for token refresh (scoped)
    FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) async {
        await repo.updateAuthToken(
          uid: firebaseUser.uid,
          token: newToken,
        );
      },
    );

  } catch (e) {
    debugPrint("Notification setup error: $e");
  }
}