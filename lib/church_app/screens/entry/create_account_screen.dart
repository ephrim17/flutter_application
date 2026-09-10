import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/input_validators.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/loading_access_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show selectedChurchProvider;
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/screens/entry/auth_navigation.dart';
import 'package:flutter_application/church_app/screens/entry/complete_profile_screen.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/services/user_identity_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Last step of sign-up (§5.5): the [ProfileDraft] collected by
/// `CompleteProfileScreen` already has everything except email/password, so
/// this screen only asks for those, creates the Firebase account, then
/// writes `users/{uid}` with the draft plus the new email in one go —
/// there is no intermediate "signed in but no identity doc" moment on this
/// path (unlike the old email-first flow), since both happen back to back
/// here before `AppEntry` ever sees the new user.
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key, required this.profileDraft});

  final ProfileDraft profileDraft;

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty) return context.t('auth.email_required');
    if (!InputValidators.isValidEmail(email)) {
      return context.t('auth.email_address_invalid');
    }
    if (password.isEmpty) return context.t('auth.password_required');
    if (password.length < 8) return context.t('auth.password_min_length');
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return context.t('auth.password_uppercase_required');
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return context.t('auth.password_number_required');
    }
    if (_confirmPasswordController.text != password) {
      return context.t('auth.passwords_mismatch');
    }
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final loadingNotifier = ref.read(logginAccessLoadingProvider.notifier);
    loadingNotifier.state = true;
    try {
      try {
        await ref.read(authRepositoryProvider).createFirebaseAccount(
              email: email,
              password: _passwordController.text,
            );
      } on FirebaseAuthException catch (error) {
        if (error.code == 'email-already-in-use') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.t('auth.account_exists_switch_to_login')),
            ),
          );
          goToSignIn(context, initialEmail: email);
          return;
        }
        rethrow;
      }

      final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
      if (uid == null) return;
      final draft = widget.profileDraft;
      await UserIdentityRepository(firestore: ref.read(firestoreProvider))
          .createIdentity(
        uid: uid,
        name: draft.name,
        email: email,
        phone: draft.phone,
        dob: draft.dob,
        gender: draft.gender,
      );

      await ChurchLocalStorage().clearChurch();
      await ChurchLocalStorage().clearSubscribedChurchTopic();
      if (!mounted) return;
      ref.read(selectedChurchProvider.notifier).state = null;
      ref.invalidate(currentChurchIdProvider);
      ref.invalidate(userIdentityProvider);
      ref.invalidate(currentMembershipProvider);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppEntry()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(error))),
      );
    } finally {
      loadingNotifier.state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(logginAccessLoadingProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(text: context.t('auth.register')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Container(
                  decoration: carouselBoxDecoration(context),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('auth.create_account_heading'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.t('auth.register_subtitle'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: context.t('auth.email_address_label'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        decoration: InputDecoration(
                          labelText: context.t('auth.password_label'),
                          helperText: context.t('auth.password_helper'),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _hidePassword = !_hidePassword,
                            ),
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _confirmPasswordController,
                        obscureText: _hideConfirmPassword,
                        decoration: InputDecoration(
                          labelText: context.t('auth.confirm_password_label'),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () =>
                                  _hideConfirmPassword = !_hideConfirmPassword,
                            ),
                            icon: Icon(
                              _hideConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SolidButton(
                  label: context.t('auth.register'),
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
