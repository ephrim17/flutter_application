import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/super_admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart';
import 'package:flutter_application/church_app/providers/loading_access_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/select-church-screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AdminModeScreen extends ConsumerWidget {
  const AdminModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChurch = ref.watch(selectedChurchProvider);
    final configAsync = ref.watch(appConfigProvider);
    final churchName = configAsync.maybeWhen(
      data: (config) {
        final title =
            config.textContent.get('church_tab.app_title', fallback: '').trim();
        if (title.isNotEmpty) return title;
        return selectedChurch?.name.trim() ?? '';
      },
      orElse: () => selectedChurch?.name.trim() ?? '',
    );
    final message = context
        .t(
          'admin_mode.message',
          fallback: "We're updating {churchName}. Please check back soon.",
        )
        .replaceAll(
            '{churchName}', churchName.isEmpty ? 'the church' : churchName);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.construction_rounded,
                  size: 54,
                  color: Colors.black87,
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You can log out and check again later.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () => _handleOkay(context, ref),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    context.t('admin_mode.okay', fallback: 'Okay'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black26),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleOkay(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    ref.read(logginAccessLoadingProvider.notifier).state = false;
    ref.read(forcePreflowThemeProvider.notifier).state = true;
    await ChurchLocalStorage().clearChurch();
    await ChurchLocalStorage().clearSubscribedChurchTopic();
    await ref.read(favoritesProvider.notifier).clearAll();
    ref.read(selectedChurchProvider.notifier).state = null;
    await ref.read(superAdminEntryModeProvider.notifier).setMode(
          SuperAdminEntryMode.normal,
        );
    ref.invalidate(currentChurchIdProvider);
    ref.invalidate(appUserProvider);
    ref.invalidate(getCurrentUserProvider);
    navigator.pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => const SelectChurchScreen(),
      ),
      (route) => false,
    );
  }
}
