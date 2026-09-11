import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/screens/entry/auth_navigation.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';

/// First screen after onboarding for anyone signed out — an explicit
/// Sign In / Sign Up choice, replacing the old email-first screen that
/// guessed which one you meant. "Sign Up" starts with `CompleteProfileScreen`
/// (name/phone/dob/gender collected before any Firebase account exists),
/// then `CreateAccountScreen` (email/password), then email-OTP verification.
/// "Sign In" goes straight to `SignInScreen` since the intent is already
/// known here.
class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
