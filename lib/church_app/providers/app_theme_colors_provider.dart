import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:flutter_application/church_app/models/app_theme_colors_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Global (not per-church) brand color overrides, read once at startup from
/// `onBoarding/appTheme`. Falls back to the hardcoded `AppColors` defaults
/// on a missing doc, a missing/blank field, or `permission-denied` (mirrors
/// `onboardingPagesProvider`'s fallback for the same collection).
final appThemeColorsProvider = FutureProvider<AppThemeColorsConfig>((ref) async {
  try {
    final doc = await ref
        .read(firestoreProvider)
        .collection('onBoarding')
        .doc(appThemeColorsDocId)
        .get();
    return AppThemeColorsConfig.fromMap(doc.data());
  } on FirebaseException catch (error) {
    if (error.code != 'permission-denied') rethrow;
    debugPrint('Using default app theme colors: ${error.message}');
    return const AppThemeColorsConfig();
  }
});
