import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/screens/entry/login_request_screen.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_application/church_app/providers/loading_access_provider.dart';

class LoginScreen extends ConsumerWidget {
  //const LoginScreen({super.key});

  final String churchId;
  final String churchName;

  const LoginScreen({
    super.key,
    required this.churchId,
    required this.churchName,
  });

  Future<bool> _showRegisterPrompt(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('User not found'),
            content: const Text(
              'No registered user was found for this church. Would you like to register as a new user?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Register'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _churchUserExistsByEmail(
    WidgetRef ref, {
    required String churchId,
    required String email,
  }) async {
    final snapshot = await FirestorePaths
        .churchUsers(ref.read(firestoreProvider), churchId)
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<void> _ensureNotificationsAfterLogin(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final isAuthorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!context.mounted) return;

    await handleNotificationSetup(
      context: context,
      ref: ref,
      promptIfNeeded: !isAuthorized,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    final isLoading = ref.watch(logginAccessLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: ref.t('auth.login', fallback: 'Login'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 📧 Email
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),

            /// 🔑 Password
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
            ),

            const SizedBox(height: 24),

            /// 🚀 Login
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        final password = passCtrl.text;

                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter your email address.'),
                            ),
                          );
                          return;
                        }

                        if (password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter your password.'),
                            ),
                          );
                          return;
                        }
                        ref.read(logginAccessLoadingProvider.notifier).state =
                            true;
                        try {
                          await ref.read(authRepositoryProvider).signIn(
                                email: email,
                                password: password,
                              );

                          final firebaseUser =
                              ref.read(firebaseAuthProvider).currentUser;
                          if (firebaseUser == null) {
                            throw Exception('Unable to fetch logged in user');
                          }

                          final userDoc = await FirestorePaths.churchUserDoc(
                            ref.read(firestoreProvider),
                            churchId,
                            firebaseUser.uid,
                          ).get();

                          ref.read(logginAccessLoadingProvider.notifier).state =
                              false;
                          if (!context.mounted) return;

                          if (!userDoc.exists) {
                            await ref.read(firebaseAuthProvider).signOut();
                            if (!context.mounted) return;

                            final shouldRegister =
                                await _showRegisterPrompt(context);

                            if (!context.mounted || !shouldRegister) return;

                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => LoginRequestScreen(
                                  churchId: churchId,
                                  churchName: churchName,
                                ),
                              ),
                            );
                            return;
                          }

                          await _ensureNotificationsAfterLogin(context, ref);
                          if (!context.mounted) return;

                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const AppEntry()),
                            (route) => false,
                          );
                        } on FirebaseAuthException catch (e) {
                          ref.read(logginAccessLoadingProvider.notifier).state =
                              false;

                          if (!context.mounted) return;

                          if (e.code == 'invalid-email') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(mapFirebaseAuthError(e))),
                            );
                            return;
                          }

                          if (e.code == 'network-request-failed' ||
                              e.code == 'too-many-requests' ||
                              e.code == 'operation-not-allowed' ||
                              e.code == 'user-disabled') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(mapFirebaseAuthError(e))),
                            );
                            return;
                          }

                          final userExistsInChurch = await _churchUserExistsByEmail(
                            ref,
                            churchId: churchId,
                            email: email,
                          );

                          if (!context.mounted) return;

                          if (!userExistsInChurch) {
                            final shouldRegister =
                                await _showRegisterPrompt(context);
                            if (!context.mounted || !shouldRegister) return;

                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => LoginRequestScreen(
                                  churchId: churchId,
                                  churchName: churchName,
                                ),
                              ),
                            );
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(mapFirebaseAuthError(e))),
                          );
                        } catch (e) {
                          ref.read(logginAccessLoadingProvider.notifier).state =
                              false;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        ref.t('auth.login', fallback: 'Login'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
