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
        final bgColor = config.primaryColorHex.toColor();

        return MaterialApp(
          theme: ThemeData(
            scaffoldBackgroundColor: bgColor.withAlpha(240),
            colorScheme: ColorScheme.fromSeed(seedColor: bgColor),
            appBarTheme: AppBarTheme(
              backgroundColor: bgColor.withAlpha(90),
              elevation: 0,
              foregroundColor: Colors.black,
            ),
          ),
          home: const AppEntry(),
        );
      },
    );
  }
}
