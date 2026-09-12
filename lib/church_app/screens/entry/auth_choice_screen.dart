import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/auth_navigation.dart';
import 'package:flutter_application/church_app/screens/entry/complete_profile_screen.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// First screen after onboarding for anyone signed out — an explicit
/// Sign In / Sign Up choice, replacing the old email-first screen that
/// guessed which one you meant. "Sign Up" starts with `CompleteProfileScreen`
/// (name/phone/dob/gender collected before any Firebase account exists),
/// then `CreateAccountScreen` (email/password), then email-OTP verification.
/// "Sign In" goes straight to `SignInScreen` since the intent is already
/// known here.
///
/// Also the landing point for an *abandoned* sign-up (a Firebase account
/// exists but its `users/{uid}` doc doesn't — `AppEntry` routes here for
/// that state too): [_AuthChoiceScreenState] detects it and pushes
/// `CompleteProfileScreen`'s resume mode on top of itself, so that screen
/// always has a real route underneath it and a working back button, instead
/// of ever being shown as a dead-end root screen.
class AuthChoiceScreen extends ConsumerStatefulWidget {
  const AuthChoiceScreen({super.key});

  @override
  ConsumerState<AuthChoiceScreen> createState() => _AuthChoiceScreenState();
}

class _AuthChoiceScreenState extends ConsumerState<AuthChoiceScreen> {
  bool _resumePushed = false;

  void _maybeResumeProfile(bool shouldResume) {
    if (!shouldResume || _resumePushed) return;
    _resumePushed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = ref.watch(authStateProvider).value;
    final identityAsync = ref.watch(userIdentityProvider);
    final needsProfileResume = firebaseUser != null &&
        identityAsync.hasValue &&
        identityAsync.value == null;
    _maybeResumeProfile(needsProfileResume);

    // Only hide the choice UI for the brief moment before the resume push
    // above actually happens — once it has (or the person backed out of it),
    // this screen must show its normal Register/Login UI, not a stuck
    // spinner, since needsProfileResume otherwise stays true forever.
    if (needsProfileResume && !_resumePushed) {
      return const Scaffold(body: Center(child: AppLoadingIndicator()));
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: welcomeBackCardDecoration(context, radius: 44),
                  child: const Icon(
                    Icons.church_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                context.t('auth.email_step_heading'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                context.t('auth.choice_subtitle'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 40),
              SolidButton(
                label: context.t('auth.register'),
                onPressed: () => goToSignUp(context),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => goToSignIn(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: BorderSide(color: theme.colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(cornerRadius),
                  ),
                ),
                child: Text(context.t('auth.login')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
