import 'package:flutter/material.dart';

/// The app's default brand color pair — striking dark green (primary) and
/// striking orange (secondary) — used for every screen, church or not.
/// There is no per-church color customization. These are the fallback
/// values; `onBoarding/appTheme` in Firestore can override both globally
/// without a release (see `appThemeColorsProvider`) — a different mechanism
/// from the old per-church `AppConfig.primaryColorHex`/etc (read from
/// `churches/{id}/config/app.theme`, editable via Studio's Theme tab), which
/// stays removed.
class AppColors {
  const AppColors._();

  static const background = Color(0xFFF5F2FA);
  static const card = Color.fromARGB(255, 255, 255, 255);
  static const darkBackground = Color(0xFF101512);
  static const darkCard = Color(0xFF1A211C);

  static const primary = Color.fromARGB(255, 31, 128, 26);
  static const secondary = Color(0xFFFF6A00);

  static const lightText = Colors.black;
  static const lightMutedText = Colors.black87;
  static const lightInput = Colors.black54;

  static const darkText = Colors.white;
  static const darkMutedText = Colors.white70;
  static const darkInput = Colors.white70;
}
