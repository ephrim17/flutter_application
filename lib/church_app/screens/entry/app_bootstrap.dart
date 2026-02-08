import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);

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
          theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: bgColor,
              colorScheme: ColorScheme.fromSeed(
                seedColor: primaryColor,
                primary: primaryColor,
                secondary: secondaryColor // 👈 force exact
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: bgColor,
                elevation: 0,
                foregroundColor: Colors.black,
              ),
              cardTheme: CardThemeData().copyWith(
                color: cardColor,
                margin:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white))),
          home: const AppEntry(),
        );
      },
    );
  }
}
