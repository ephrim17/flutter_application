import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/models/text_content_defaults.dart';

String mapFirebaseAuthError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return defaultChurchTextContents['auth.invalid_email']!;
      case 'user-not-found':
        return defaultChurchTextContents['auth.user_not_found']!;
      case 'wrong-password':
        return defaultChurchTextContents['auth.wrong_password']!;
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return defaultChurchTextContents['auth.invalid_credentials']!;
      case 'requires-recent-login':
        return defaultChurchTextContents['auth.recent_login_required']!;
      case 'no-current-user':
        return defaultChurchTextContents['auth.no_signed_in_user']!;
      case 'missing-email':
        return defaultChurchTextContents['auth.email_verification_failed']!;
      case 'user-disabled':
        return defaultChurchTextContents['auth.user_disabled']!;
      case 'email-already-in-use':
        return defaultChurchTextContents['auth.email_in_use']!;
      case 'weak-password':
        return defaultChurchTextContents['auth.weak_password']!;
      case 'expired-action-code':
        return defaultChurchTextContents['auth.expired_action_code']!;
      case 'invalid-action-code':
        return defaultChurchTextContents['auth.invalid_action_code']!;
      case 'network-request-failed':
        return defaultChurchTextContents['auth.network_error']!;
      case 'too-many-requests':
      case 'too-many-attempts':
        return defaultChurchTextContents['auth.too_many_requests']!;
      case 'reset-code-failed':
        return defaultChurchTextContents['auth.reset_code_failed']!;
      case 'invalid-code':
        return defaultChurchTextContents['auth.reset_code_invalid']!;
      case 'expired-code':
        return defaultChurchTextContents['auth.reset_code_expired']!;
      case 'invalid-reset-session':
        return defaultChurchTextContents['auth.reset_session_invalid']!;
      case 'password-reset-failed':
        return defaultChurchTextContents['auth.password_reset_failed']!;
      case 'operation-not-allowed':
        return defaultChurchTextContents['auth.operation_not_allowed']!;
      default:
        return defaultChurchTextContents['auth.generic_error']!;
    }
  }

  return defaultChurchTextContents['auth.unexpected_error']!;
}
