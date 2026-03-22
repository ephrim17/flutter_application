import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/screens/side_drawer/settings_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);
    final forcePreflowTheme = ref.watch(forcePreflowThemeProvider);
    final themeMode = ref.watch(themeProvider);

    return configAsync.when(
      loading: () => MaterialApp(
        theme: _buildTheme(
          context: context,
          brightness: Brightness.light,
          bgColor: Colors.black,
          cardColor: const Color(0xFF161616),
          primaryColor: Colors.white,
          secondaryColor: Colors.white,
        ),
        darkTheme: _buildTheme(
          context: context,
          brightness: Brightness.dark,
          bgColor: Colors.black,
          cardColor: const Color(0xFF161616),
          primaryColor: Colors.white,
          secondaryColor: Colors.white,
        ),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => MaterialApp(
        theme: _buildTheme(
          context: context,
          brightness: Brightness.light,
          bgColor: Colors.black,
          cardColor: const Color(0xFF161616),
          primaryColor: Colors.white,
          secondaryColor: Colors.white,
        ),
        darkTheme: _buildTheme(
          context: context,
          brightness: Brightness.dark,
          bgColor: Colors.black,
          cardColor: const Color(0xFF161616),
          primaryColor: Colors.white,
          secondaryColor: Colors.white,
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
            : Colors.black;
        final cardColor = useChurchTheme
            ? config.cardColorHex.toColor()
            : const Color(0xFF161616);
        final primaryColor = useChurchTheme
            ? config.primaryColorHex.toColor()
            : Colors.white;
        final secondaryColor = useChurchTheme
            ? config.secondaryColorHex.toColor()
            : Colors.white;

        return MaterialApp(
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
            bgColor: Colors.black,
            cardColor: const Color(0xFF1E1E1E),
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
  final textColor = usesDarkSurface ? Colors.white : Colors.black;
  final mutedTextColor = usesDarkSurface ? Colors.white70 : Colors.black87;
  final inputColor = usesDarkSurface ? Colors.white70 : Colors.black54;

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
