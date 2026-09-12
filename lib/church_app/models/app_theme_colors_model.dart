import 'package:flutter/material.dart';

/// Doc id, inside the global `onBoarding` collection, holding the app-wide
/// brand color overrides — kept in the same collection as the onboarding
/// walkthrough slides (per product decision), but excluded from that slide
/// listing by id (see `onboardingPagesProvider`).
const appThemeColorsDocId = 'appTheme';

/// Optional Firestore-supplied overrides for [AppColors.primary]/
/// [AppColors.secondary]. Applies to every church — there is no per-church
/// variant. Either field left `null` (missing, blank, or unparseable in
/// Firestore) falls back to the hardcoded `AppColors` default.
class AppThemeColorsConfig {
  final Color? primary;
  final Color? secondary;

  const AppThemeColorsConfig({this.primary, this.secondary});

  factory AppThemeColorsConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AppThemeColorsConfig();
    return AppThemeColorsConfig(
      primary: _parseHexColor(map['primaryColor']),
      secondary: _parseHexColor(map['secondaryColor']),
    );
  }
}

/// Parses a `#RRGGBB` / `#AARRGGBB` (leading `#` optional) hex string into a
/// [Color]. Returns null for anything else, so a typo in Firestore falls
/// back to the default rather than crashing or rendering black.
Color? _parseHexColor(dynamic value) {
  if (value is! String) return null;
  var hex = value.trim().replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}
