
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    var lightColorScheme = ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 191, 139, 255),);

    return config.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text("BootStrap Launch failed")),
      ),
      data: (_) => MaterialApp(
        theme: ThemeData().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 250, 250),
        colorScheme: lightColorScheme,
      ),
      home: AppEntry()
      ),
    );
  }
}
