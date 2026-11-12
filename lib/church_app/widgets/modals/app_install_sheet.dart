import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_install.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/install_guide.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';

/// "How do I keep this on my phone?" answered for the browser the reader is
/// actually using.
///
/// Chromium browsers hand the page a real install prompt, so the button does
/// the work. Safari and Firefox never do — there the written steps are the
/// whole answer, which is why they are not a footnote under the button.
Future<void> showAppInstallSheet(BuildContext context) {
  return showAppModalBottomSheet<void>(
    context: context,
    builder: (_) => const AppInstallSheet(),
  );
}

class AppInstallSheet extends StatefulWidget {
  const AppInstallSheet({super.key});

  @override
  State<AppInstallSheet> createState() => _AppInstallSheetState();
}

class _AppInstallSheetState extends State<AppInstallSheet> {
  late final InstallGuide _guide =
      installGuideForUserAgent(currentBrowserUserAgent());
  late bool _canPrompt = isInstallPromptAvailable();
  bool _busy = false;

  Future<void> _install() async {
    if (_busy) return;
    setState(() => _busy = true);

    final outcome = await requestAppInstall();
    if (!mounted) return;

    setState(() {
      _busy = false;
      // The browser spends the prompt on a single use, whatever was chosen.
      _canPrompt = isInstallPromptAvailable();
    });

    if (outcome == 'accepted') {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('install.accepted'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final steps = installGuideStepCount(_guide);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.add_to_home_screen_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.t('install.sheet_title'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context.t('install.sheet_intro'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (_canPrompt) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _install,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(context.t('install.install_button')),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.t('install.manual_heading'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              context.t(installGuideTitleKey(_guide)),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (var step = 1; step <= steps; step++) ...[
              if (step > 1) const SizedBox(height: 12),
              _InstallStep(
                number: step,
                text: context.t(installGuideStepKey(_guide, step)),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.t('common.close')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstallStep extends StatelessWidget {
  const _InstallStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSecondaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}
