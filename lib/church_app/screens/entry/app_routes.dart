import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/entry/reset_password_screen.dart';

Route<dynamic>? generateChurchAppRoute(RouteSettings settings) {
  final routeName = settings.name;
  if (routeName == null || routeName == '/') return null;

  final uri = Uri.tryParse(routeName);
  if (uri == null) return null;

  if (uri.path == '/reset-password') {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => ResetPasswordScreen(
        oobCode: uri.queryParameters['oobCode'] ?? '',
        email: uri.queryParameters['email'] ?? '',
        churchName: uri.queryParameters['churchName'] ?? '',
      ),
    );
  }

  return null;
}
