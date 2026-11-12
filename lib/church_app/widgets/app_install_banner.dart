import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_install.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/install_guide.dart';
import 'package:flutter_application/church_app/widgets/modals/app_install_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one place a browser visitor is told they can keep this app.
///
/// Nothing in a browser says "this can live on your home screen", and the
/// browser's own mini-infobar is suppressed so the offer can be made here,
/// with a sentence explaining what it does. It shows on the web only, never
/// once the app is already running from the home screen, and it takes "Not
/// now" for an answer — permanently, on that device. Settings keeps a
/// permanent entry so dismissing it does not hide the feature for good.
class AppInstallBanner extends StatefulWidget {
  const AppInstallBanner({super.key});

  /// Remembered per device, not per account: installing is a property of
  /// the browser you are standing in front of.
  static const String dismissedPreferenceKey = 'app_install_banner_dismissed';

  @override
  State<AppInstallBanner> createState() => _AppInstallBannerState();
}

class _AppInstallBannerState extends State<AppInstallBanner> {
  /// Null while we are still asking; nothing is drawn until we know, so the
  /// banner never flashes up and then vanishes.
  bool? _visible;

  @override
  void initState() {
    super.initState();
    _resolveVisibility();
  }

  Future<void> _resolveVisibility() async {
    if (!kIsWeb || isRunningAsInstalledApp()) {
      if (mounted) setState(() => _visible = false);
      return;
    }

    bool dismissed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      dismissed =
          prefs.getBool(AppInstallBanner.dismissedPreferenceKey) ?? false;
    } catch (_) {
      // A browser with storage blocked just gets the offer again.
    }

    if (!mounted) return;
    setState(() {
      _visible = shouldOfferAppInstall(
        isWeb: kIsWeb,
        alreadyInstalled: isRunningAsInstalledApp(),
        dismissed: dismissed,
      );
    });
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppInstallBanner.dismissedPreferenceKey, true);
    } catch (_) {
      // Not worth telling anyone about: the banner is already gone for
      // this visit, and the Settings entry remains.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_visible != true) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // The banner carries its own top gap rather than being wrapped in one,
    // so a build where it draws nothing leaves no band of empty page behind
    // it — the same rule the For You sections follow.
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.add_to_home_screen_rounded,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('install.banner_title'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('install.banner_body'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: () => showAppInstallSheet(context),
                      child: Text(context.t('install.banner_action')),
                    ),
                    TextButton(
                      onPressed: _dismiss,
                      child: Text(context.t('install.banner_dismiss')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
