import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/loading_access_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show selectedChurchProvider;
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/screens/entry/login_request_screen.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LoginScreen extends ConsumerWidget {
  //const LoginScreen({super.key});

  final String churchId;
  final String churchName;
  final String churchLogo;

  const LoginScreen({
    super.key,
    required this.churchId,
    required this.churchName,
    this.churchLogo = '',
  });

  Future<bool> _showRegisterPrompt(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              context.t(
                'auth.user_not_found_title',
                fallback: 'User not found',
              ),
            ),
            content: Text(
              context.t(
                'auth.user_not_found_message',
                fallback:
                    'No registered user was found for this church. Would you like to register as a new user?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  context.t('settings.cancel', fallback: 'Cancel'),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  context.t('auth.register', fallback: 'Register'),
                ),
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
    final snapshot =
        await FirestorePaths.churchUsers(ref.read(firestoreProvider), churchId)
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get();

    return snapshot.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    final isLoading = ref.watch(logginAccessLoadingProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(
          text: ref.t('auth.login', fallback: 'Login'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LinearScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 12),
                ChurchLogoAvatar(
                  logo: churchLogo,
                  size: 84,
                ),
                const SizedBox(height: 14),
                Text(
                  churchName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: carouselBoxDecoration(context),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      /// 📧 Email
                      TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                        ),
                      ),
                      const SizedBox(height: 16),

                      /// 🔑 Password
                      TextField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                /// 🚀 Login
                SolidButton(
                  label: ref.t('auth.login', fallback: 'Login'),
                  isLoading: isLoading,
                  onPressed: isLoading
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          final password = passCtrl.text;

                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Please enter your email address.'),
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

                            ref
                                .read(logginAccessLoadingProvider.notifier)
                                .state = false;
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
                                    churchLogo: churchLogo,
                                  ),
                                ),
                              );
                              return;
                            }

                            final appUser = AppUser.fromJson(
                              userDoc.data() as Map<String, dynamic>,
                            );
                            ref.read(selectedChurchProvider.notifier).state =
                                Church(
                              id: churchId,
                              name: churchName,
                              address: '',
                              contact: '',
                              email: '',
                              pastorName: '',
                              logo: churchLogo,
                              enabled: true,
                            );
                            ref.invalidate(currentChurchIdProvider);
                            unawaited(
                              syncNotificationTopicIfAuthorized(ref),
                            );

                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => AppEntry(initialUser: appUser),
                              ),
                              (route) => false,
                            );
                          } on FirebaseAuthException catch (e) {
                            ref
                                .read(logginAccessLoadingProvider.notifier)
                                .state = false;

                            if (!context.mounted) return;

                            if (e.code == 'invalid-email') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(mapFirebaseAuthError(e))),
                              );
                              return;
                            }

                            if (e.code == 'network-request-failed' ||
                                e.code == 'too-many-requests' ||
                                e.code == 'operation-not-allowed' ||
                                e.code == 'user-disabled') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(mapFirebaseAuthError(e))),
                              );
                              return;
                            }

                            final userExistsInChurch =
                                await _churchUserExistsByEmail(
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
                                    churchLogo: churchLogo,
                                  ),
                                ),
                              );
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(mapFirebaseAuthError(e))),
                            );
                          } catch (e) {
                            ref
                                .read(logginAccessLoadingProvider.notifier)
                                .state = false;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
