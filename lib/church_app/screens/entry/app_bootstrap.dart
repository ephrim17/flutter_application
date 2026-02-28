import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/screens/side_drawer/settings_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);
     // 👇 watch theme mode here
    final themeMode = ref.watch(themeProvider);

    return configAsync.when(
      loading: () => const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const MaterialApp(
        home: Scaffold(
          body: Center(child: Text("Bootstrap Launch failed")),
        ),
      ),
      data: (config) {
        final bgColor = config.backgroundColorHex.toColor();
        final cardColor = config.cardColorHex.toColor();
        final primaryColor = config.primaryColorHex.toColor();
        final secondaryColor = config.secondaryColorHex.toColor();

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
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,

    scaffoldBackgroundColor: bgColor,

    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      brightness: brightness,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: bgColor,
      elevation: 0,
      foregroundColor: isDark ? Colors.white : Colors.black,
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
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    ),

    textTheme: ThemeData().textTheme.copyWith(
      titleLarge: GoogleFonts.anekTamil(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black,
      ),
      headlineMedium: GoogleFonts.anekTamil(
        color: isDark ? Colors.white : Colors.black,
      ),
        headlineLarge: GoogleFonts.anekTamil(
          color: isDark ? Colors.white : Colors.black,
        ),
      titleMedium: GoogleFonts.anekTamil(
        color: isDark ? Colors.white : Colors.black,
      ),
      bodyMedium: GoogleFonts.anekTamil(
        color: isDark ? Colors.white : Colors.black,
        //fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.anekTamil(
        color: isDark ? Colors.white : Colors.black,
      ),
      bodySmall: GoogleFonts.anekTamil(
        color: isDark ? Colors.white70 : Colors.black87,
      ),
      labelLarge: GoogleFonts.anekTamil(
        color: isDark ? Theme.of(context).colorScheme.primaryContainer :  primaryColor,
      ),
    ),
  );
}
