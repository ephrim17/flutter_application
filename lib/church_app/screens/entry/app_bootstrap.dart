
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

    return MaterialApp(
      home: configAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const Scaffold(
          body: Center(child: Text("Bootstrap Launch failed")),
        ),
        data: (config) {
          final bgColor = config.primaryColorHex.toColor();

          return Theme(
            data: ThemeData(
              scaffoldBackgroundColor: bgColor,
              colorScheme: ColorScheme.fromSeed(seedColor: bgColor),
            ),
            child: AppEntry(),
          );
        },
      ),
    );
  }
}
