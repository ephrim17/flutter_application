import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/entry/complete_profile_screen.dart';
import 'package:flutter_application/church_app/screens/entry/create_account_screen.dart';
import 'package:flutter_application/church_app/screens/entry/sign_in_screen.dart';

/// Switches to Sign In or Sign Up without letting the stack grow every time
/// someone bounces between them — `AuthChoiceScreen` is always the base of
/// this mini-flow (it's rendered inline by `AppEntry`, itself reached via
/// `pushAndRemoveUntil` at every entry point, so it's always `route.isFirst`
/// on this navigator) — collapsing back to it before pushing the target
/// keeps the stack at a predictable depth of two, no matter how many times
/// someone toggles between "Login" and "Register" links.
void goToSignIn(BuildContext context, {String initialEmail = ''}) {
  final navigator = Navigator.of(context);
  navigator.popUntil((route) => route.isFirst);
  navigator.push(
    MaterialPageRoute(
      builder: (_) => SignInScreen(initialEmail: initialEmail),
    ),
  );
}

void goToSignUp(BuildContext context) {
  final navigator = Navigator.of(context);
  navigator.popUntil((route) => route.isFirst);
  navigator.push(
    MaterialPageRoute(
      builder: (_) => CompleteProfileScreen(
        onContinue: (draft) => navigator.push(
          MaterialPageRoute(
            builder: (_) => CreateAccountScreen(profileDraft: draft),
          ),
        ),
      ),
    ),
  );
}
