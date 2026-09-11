import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_system_ui_overlay.dart';
import 'package:flutter_application/church_app/helpers/app_colors.dart';
import 'package:flutter_application/church_app/models/user_identity_model.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/app_routes.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/screens/side_drawer/settings_screen.dart';
import 'package:flutter_application/church_app/services/user_identity_repository.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  static const _minimumSplashDuration = Duration(seconds: 3);

  String? _lastDailyStreakSyncKey;
  bool _minimumSplashElapsed = false;

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  // Global — one streak per person, not per membership (D4), so this no
  // longer needs a selected church at all (fixes §2.6-adjacent: a church-less
  // guest still ticks the streak).
  Future<void> _syncDailyStreakIfNeeded(UserIdentity user) async {
    if (!mounted) return;

    final today = DateTime.now();
    if (user.lastStreakRecordedAt != null &&
        _isSameDay(user.lastStreakRecordedAt!, today)) {
      return;
    }

    final syncKey = '${user.uid}:${today.year}-${today.month}-${today.day}';
    if (_lastDailyStreakSyncKey == syncKey) return;

    _lastDailyStreakSyncKey = syncKey;
    final repository = UserIdentityRepository(
      firestore: ref.read(firestoreProvider),
    );

    try {
      await repository.updateDailyStreak(user.uid);
    } catch (_) {
      _lastDailyStreakSyncKey = null;
    }
  }

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(_minimumSplashDuration, () {
      if (!mounted) return;
      setState(() {
        _minimumSplashElapsed = true;
      });
    });

    ref.listenManual(currentChurchIdProvider, (previous, next) {
      next.whenData((churchId) async {
        await FirebaseAnalytics.instance.setUserProperty(
          name: 'church_id',
          value: churchId?.trim().isEmpty ?? true ? null : churchId,
        );
      });
    }, fireImmediately: true);

    ref.listenManual(userIdentityProvider, (previous, next) async {
      final user = next.asData?.value;
      if (user == null) return;
      await _syncDailyStreakIfNeeded(user);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final analyticsObserver = FirebaseAnalyticsObserver(
      analytics: FirebaseAnalytics.instance,
    );
    final themeMode = ref.watch(themeProvider);

    // One brand theme everywhere — no per-church color customization, so
    // there's nothing here to wait on before picking a theme.
    return MaterialApp(
      builder: buildAppSystemUiOverlay,
      navigatorObservers: [analyticsObserver],
      onGenerateRoute: generateChurchAppRoute,
      themeMode: themeMode,
      theme: _buildTheme(
        context: context,
        brightness: Brightness.light,
        bgColor: AppColors.background,
        cardColor: AppColors.card,
        primaryColor: AppColors.primary,
        secondaryColor: AppColors.secondary,
      ),
      darkTheme: _buildTheme(
        context: context,
        brightness: Brightness.dark,
        bgColor: AppColors.darkBackground,
        cardColor: AppColors.darkCard,
        primaryColor: AppColors.primary,
        secondaryColor: AppColors.secondary,
      ),
      home: _minimumSplashElapsed
          ? const AppEntry()
          : const Scaffold(
              body: Center(child: AppLoadingIndicator()),
            ),
    );
  }
}

ThemeData _buildTheme({
  required BuildContext context,
  required Brightness brightness,
  required Color bgColor,
  required Color cardColor,
  required Color primaryColor,
  required Color secondaryColor,
}) {
  final usesDarkSurface = bgColor.computeLuminance() < 0.2;
  final buttonForegroundColor =
      primaryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  final textColor = usesDarkSurface ? AppColors.darkText : AppColors.lightText;
  final mutedTextColor =
      usesDarkSurface ? AppColors.darkMutedText : AppColors.lightMutedText;
  final inputColor =
      usesDarkSurface ? AppColors.darkInput : AppColors.lightInput;
  final errorColor =
      usesDarkSurface ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A);
  final interTextTheme = _reduceTextThemeFontSizes(
    GoogleFonts.interTextTheme(ThemeData(brightness: brightness).textTheme),
    3,
  );

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: bgColor,
    canvasColor: cardColor,
    dividerColor: mutedTextColor.withAlpha(40),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      brightness: brightness,
      surface: cardColor,
      error: errorColor,
      onError: Colors.white,
      onPrimary: buttonForegroundColor,
      onSecondary: buttonForegroundColor,
      onSurface: textColor,
    ),
    iconTheme: IconThemeData(color: inputColor),
    appBarTheme: AppBarTheme(
      backgroundColor: bgColor,
      elevation: 0,
      foregroundColor: textColor,
      systemOverlayStyle: appSystemUiOverlayStyleFor(bgColor),
      titleTextStyle: GoogleFonts.inter(
        color: textColor,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.35,
      ),
    ),
    cardTheme: CardThemeData().copyWith(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        side: BorderSide(
          color: primaryColor,
          width: 1.5,
        ),
        foregroundColor: primaryColor,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: buttonForegroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: buttonForegroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: cardColor,
      contentTextStyle: TextStyle(color: textColor),
      actionTextColor: primaryColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardColor,
      surfaceTintColor: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      titleTextStyle: GoogleFonts.inter(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.35,
      ),
      contentTextStyle: GoogleFonts.inter(
        color: textColor,
        fontSize: 11,
        height: 1.5,
        letterSpacing: -0.08,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardColor,
      surfaceTintColor: cardColor,
      modalBackgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      dragHandleColor: mutedTextColor,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      labelStyle: TextStyle(color: inputColor),
      floatingLabelStyle: TextStyle(color: primaryColor),
      helperStyle: TextStyle(color: inputColor),
      hintStyle: TextStyle(color: inputColor),
      prefixIconColor: inputColor,
      suffixIconColor: inputColor,
      errorStyle: TextStyle(color: errorColor),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: inputColor),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: inputColor),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Colors.green,
      linearTrackColor: mutedTextColor.withAlpha(40),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: cardColor,
      surfaceTintColor: cardColor,
      headerBackgroundColor: cardColor,
      headerForegroundColor: textColor,
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return buttonForegroundColor;
        }
        return textColor;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return null;
      }),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return buttonForegroundColor;
        }
        return textColor;
      }),
      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return null;
      }),
      todayForegroundColor: WidgetStatePropertyAll(Colors.green),
      todayBackgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      dividerColor: mutedTextColor.withAlpha(30),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: textColor,
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: textColor,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    textTheme: interTextTheme.copyWith(
      displayLarge: interTextTheme.displayLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        height: 1.08,
        letterSpacing: -1.2,
      ),
      displayMedium: interTextTheme.displayMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.9,
      ),
      displaySmall: interTextTheme.displaySmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        height: 1.12,
        letterSpacing: -0.65,
      ),
      titleLarge: interTextTheme.titleLarge?.copyWith(
        fontSize: 27,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.2,
        letterSpacing: -0.55,
      ),
      headlineMedium: interTextTheme.headlineMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        height: 1.18,
        letterSpacing: -0.5,
      ),
      headlineLarge: interTextTheme.headlineLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        height: 1.16,
        letterSpacing: -0.6,
      ),
      headlineSmall: interTextTheme.headlineSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.4,
      ),
      titleMedium: interTextTheme.titleMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.25,
      ),
      titleSmall: interTextTheme.titleSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.15,
      ),
      bodyMedium: interTextTheme.bodyMedium?.copyWith(
        color: textColor,
        height: 1.5,
        letterSpacing: -0.08,
      ),
      bodyLarge: interTextTheme.bodyLarge?.copyWith(
        color: textColor,
        height: 1.5,
        letterSpacing: -0.12,
      ),
      bodySmall: interTextTheme.bodySmall?.copyWith(
        color: mutedTextColor,
        height: 1.45,
        letterSpacing: 0,
      ),
      labelLarge: interTextTheme.labelLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.05,
      ),
      labelMedium: interTextTheme.labelMedium?.copyWith(
        color: mutedTextColor,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelSmall: interTextTheme.labelSmall?.copyWith(
        color: mutedTextColor,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.05,
      ),
    ),
  );
}

TextTheme _reduceTextThemeFontSizes(TextTheme theme, double amount) {
  return theme.copyWith(
    displayLarge: _reduceTextStyleFontSize(theme.displayLarge, amount),
    displayMedium: _reduceTextStyleFontSize(theme.displayMedium, amount),
    displaySmall: _reduceTextStyleFontSize(theme.displaySmall, amount),
    headlineLarge: _reduceTextStyleFontSize(theme.headlineLarge, amount),
    headlineMedium: _reduceTextStyleFontSize(theme.headlineMedium, amount),
    headlineSmall: _reduceTextStyleFontSize(theme.headlineSmall, amount),
    titleLarge: _reduceTextStyleFontSize(theme.titleLarge, amount),
    titleMedium: _reduceTextStyleFontSize(theme.titleMedium, amount),
    titleSmall: _reduceTextStyleFontSize(theme.titleSmall, amount),
    bodyLarge: _reduceTextStyleFontSize(theme.bodyLarge, amount),
    bodyMedium: _reduceTextStyleFontSize(theme.bodyMedium, amount),
    bodySmall: _reduceTextStyleFontSize(theme.bodySmall, amount),
    labelLarge: _reduceTextStyleFontSize(theme.labelLarge, amount),
    labelMedium: _reduceTextStyleFontSize(theme.labelMedium, amount),
    labelSmall: _reduceTextStyleFontSize(theme.labelSmall, amount),
  );
}

TextStyle? _reduceTextStyleFontSize(TextStyle? style, double amount) {
  final fontSize = style?.fontSize;
  if (style == null || fontSize == null) return style;
  return style.copyWith(
    fontSize: (fontSize - amount).clamp(1.0, double.infinity).toDouble(),
  );
}
