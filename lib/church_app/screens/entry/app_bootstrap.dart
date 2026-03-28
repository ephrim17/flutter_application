import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/preflow_colors.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
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
  String? _lastDailyStreakSyncKey;

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

    return configAsync.when(
      loading: () => MaterialApp(
        navigatorObservers: [analyticsObserver],
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
          bgColor: PreflowColors.background,
          cardColor: PreflowColors.card,
          primaryColor: PreflowColors.accent,
          secondaryColor: PreflowColors.accent,
        ),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => MaterialApp(
        navigatorObservers: [analyticsObserver],
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
          bgColor: PreflowColors.background,
          cardColor: PreflowColors.card,
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
        final primaryColor = useChurchTheme
            ? config.primaryColorHex.toColor()
            : PreflowColors.accent;
        final secondaryColor = useChurchTheme
            ? config.secondaryColorHex.toColor()
            : PreflowColors.accent;

        return MaterialApp(
          navigatorObservers: [analyticsObserver],
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
            bgColor: useChurchTheme ? Colors.black : PreflowColors.background,
            cardColor:
                useChurchTheme ? const Color(0xFF1E1E1E) : PreflowColors.card,
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
      onPrimary: buttonForegroundColor,
      onSecondary: buttonForegroundColor,
      onSurface: textColor,
    ),
    iconTheme: IconThemeData(color: inputColor),
    appBarTheme: AppBarTheme(
      backgroundColor: bgColor,
      elevation: 0,
      foregroundColor: textColor,
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
      titleTextStyle: GoogleFonts.anekTamil(
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: GoogleFonts.anekTamil(
        color: textColor,
        fontSize: 16,
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
      errorStyle: const TextStyle(color: Colors.white70),
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
    textTheme: ThemeData().textTheme.copyWith(
          titleLarge: GoogleFonts.anekTamil(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          headlineMedium: GoogleFonts.anekTamil(
            color: textColor,
          ),
          headlineLarge: GoogleFonts.anekTamil(
            color: textColor,
          ),
          headlineSmall: GoogleFonts.anekTamil(
            color: textColor,
          ),
          titleMedium: GoogleFonts.anekTamil(
            color: textColor,
          ),
          bodyMedium: GoogleFonts.anekTamil(
            color: textColor,
            //fontWeight: FontWeight.w600,
          ),
          bodyLarge: GoogleFonts.anekTamil(
            color: textColor,
          ),
          bodySmall: GoogleFonts.anekTamil(
            color: mutedTextColor,
          ),
          labelLarge: GoogleFonts.anekTamil(
            color: buttonForegroundColor,
          ),
          labelMedium: GoogleFonts.anekTamil(
            color: mutedTextColor,
          ),
        ),
  );
}
