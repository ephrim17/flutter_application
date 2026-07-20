import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_splash_screen.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/preflow_colors.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/app_routes.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/screens/side_drawer/settings_screen.dart';
import 'package:flutter_application/church_app/services/church_user_repository.dart';
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

  Future<void> _syncDailyStreakIfNeeded(AppUser user) async {
    final churchId = await ref.read(currentChurchIdProvider.future);
    if (churchId == null || !mounted) return;

    final today = DateTime.now();
    if (user.lastStreakRecordedAt != null &&
        _isSameDay(user.lastStreakRecordedAt!, today)) {
      return;
    }

    final syncKey =
        '$churchId:${user.uid}:${today.year}-${today.month}-${today.day}';
    if (_lastDailyStreakSyncKey == syncKey) return;

    _lastDailyStreakSyncKey = syncKey;
    final repository = ChurchUsersRepository(
      firestore: ref.read(firestoreProvider),
      churchId: churchId,
    );

    try {
      await repository.updateDailyStreak(uid: user.uid);
      ref.invalidate(appUserProvider);
      ref.invalidate(getCurrentUserProvider);
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = await ref.read(getCurrentUserProvider.future);
      if (user != null) {
        await _syncDailyStreakIfNeeded(user);
      }
    });

    ref.listenManual(currentChurchIdProvider, (previous, next) {
      next.whenData((churchId) async {
        await FirebaseAnalytics.instance.setUserProperty(
          name: 'church_id',
          value: churchId?.trim().isEmpty ?? true ? null : churchId,
        );
      });
    }, fireImmediately: true);

    ref.listenManual(appUserProvider, (previous, next) async {
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
    final configAsync = ref.watch(appConfigProvider);
    final forcePreflowTheme = ref.watch(forcePreflowThemeProvider);
    final themeMode = ref.watch(themeProvider);

    if (!_minimumSplashElapsed) {
      return MaterialApp(
        navigatorObservers: [analyticsObserver],
        onGenerateRoute: generateChurchAppRoute,
        themeMode: themeMode,
        theme: _buildTheme(
          context: context,
          brightness: Brightness.light,
          bgColor: PreflowColors.background,
          cardColor: PreflowColors.card,
          primaryColor: PreflowColors.accent,
          secondaryColor: PreflowColors.accent,
        ),
        darkTheme: _buildTheme(
          context: context,
          brightness: Brightness.dark,
          bgColor: PreflowColors.darkBackground,
          cardColor: PreflowColors.darkCard,
          primaryColor: PreflowColors.accent,
          secondaryColor: PreflowColors.accent,
        ),
        home: const Scaffold(
          body: Center(child: AppSplashScreen()),
        ),
      );
    }

    return configAsync.when(
      loading: () => MaterialApp(
        navigatorObservers: [analyticsObserver],
        onGenerateRoute: generateChurchAppRoute,
        themeMode: themeMode,
        theme: _buildTheme(
          context: context,
          brightness: Brightness.light,
          bgColor: PreflowColors.background,
          cardColor: PreflowColors.card,
          primaryColor: PreflowColors.accent,
          secondaryColor: PreflowColors.accent,
        ),
        darkTheme: _buildTheme(
          context: context,
          brightness: Brightness.dark,
          bgColor: PreflowColors.darkBackground,
          cardColor: PreflowColors.darkCard,
          primaryColor: PreflowColors.accent,
          secondaryColor: PreflowColors.accent,
        ),
        home: const Scaffold(
          body: Center(child: AppSplashScreen()),
        ),
      ),
      error: (_, __) => MaterialApp(
        navigatorObservers: [analyticsObserver],
        onGenerateRoute: generateChurchAppRoute,
        themeMode: themeMode,
        theme: _buildTheme(
          context: context,
          brightness: Brightness.light,
          bgColor: PreflowColors.background,
          cardColor: PreflowColors.card,
          primaryColor: PreflowColors.accent,
          secondaryColor: PreflowColors.accent,
        ),
        darkTheme: _buildTheme(
          context: context,
          brightness: Brightness.dark,
          bgColor: PreflowColors.darkBackground,
          cardColor: PreflowColors.darkCard,
          primaryColor: PreflowColors.accent,
          secondaryColor: PreflowColors.accent,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: Text(
                context.t(
                  'app.bootstrap_failed',
                  fallback: 'Bootstrap Launch failed',
                ),
              ),
            ),
          ),
        ),
      ),
      data: (config) {
        final useChurchTheme = !forcePreflowTheme;

        final bgColor = useChurchTheme
            ? config.backgroundColorHex.toColor()
            : PreflowColors.background;
        final cardColor =
            useChurchTheme ? config.cardColorHex.toColor() : PreflowColors.card;
        final darkBgColor =
            useChurchTheme ? Colors.black : PreflowColors.darkBackground;
        final darkCardColor =
            useChurchTheme ? const Color(0xFF1E1E1E) : PreflowColors.darkCard;
        final primaryColor = useChurchTheme
            ? config.primaryColorHex.toColor()
            : PreflowColors.accent;
        final secondaryColor = useChurchTheme
            ? config.secondaryColorHex.toColor()
            : PreflowColors.accent;

        return MaterialApp(
          navigatorObservers: [analyticsObserver],
          onGenerateRoute: generateChurchAppRoute,
          themeMode: themeMode,
          theme: _buildTheme(
            context: context,
            brightness: Brightness.light,
            bgColor: bgColor,
            cardColor: cardColor,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),
          darkTheme: _buildTheme(
            context: context,
            brightness: Brightness.dark,
            bgColor: darkBgColor,
            cardColor: darkCardColor,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),
          home: const AppEntry(),
        );
      },
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
  final textColor =
      usesDarkSurface ? PreflowColors.darkText : PreflowColors.lightText;
  final mutedTextColor = usesDarkSurface
      ? PreflowColors.darkMutedText
      : PreflowColors.lightMutedText;
  final inputColor =
      usesDarkSurface ? PreflowColors.darkInput : PreflowColors.lightInput;
  final errorColor =
      usesDarkSurface ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A);
  final poppinsTextTheme = _reduceTextThemeFontSizes(
    GoogleFonts.poppinsTextTheme(ThemeData(brightness: brightness).textTheme),
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
      titleTextStyle: GoogleFonts.poppins(
        color: textColor,
        fontSize: 19,
        fontWeight: FontWeight.w700,
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
      titleTextStyle: GoogleFonts.poppins(
        color: textColor,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: GoogleFonts.poppins(
        color: textColor,
        fontSize: 13,
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
    textTheme: poppinsTextTheme.copyWith(
      titleLarge: poppinsTextTheme.titleLarge?.copyWith(
        fontSize: 27,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineMedium: poppinsTextTheme.headlineMedium?.copyWith(
        color: textColor,
      ),
      headlineLarge: poppinsTextTheme.headlineLarge?.copyWith(
        color: textColor,
      ),
      headlineSmall: poppinsTextTheme.headlineSmall?.copyWith(
        color: textColor,
      ),
      titleMedium: poppinsTextTheme.titleMedium?.copyWith(
        color: textColor,
      ),
      titleSmall: poppinsTextTheme.titleSmall?.copyWith(
        color: textColor,
      ),
      bodyMedium: poppinsTextTheme.bodyMedium?.copyWith(
        color: textColor,
      ),
      bodyLarge: poppinsTextTheme.bodyLarge?.copyWith(
        color: textColor,
      ),
      bodySmall: poppinsTextTheme.bodySmall?.copyWith(
        color: mutedTextColor,
      ),
      labelLarge: poppinsTextTheme.labelLarge?.copyWith(
        color: textColor,
      ),
      labelMedium: poppinsTextTheme.labelMedium?.copyWith(
        color: mutedTextColor,
      ),
      labelSmall: poppinsTextTheme.labelSmall?.copyWith(
        color: mutedTextColor,
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
