import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/verse_image_generation_progress.dart';

/// A modal, non-dismissible progress dialog showing a percentage.
///
/// Used for work that costs the church money and must not be interrupted or
/// started twice — Studio's Daily Verse image generation. Being a modal
/// barrier is what disables interaction with the screen underneath; the
/// [PopScope] stops the Android back gesture dismissing it and leaving a
/// generation running invisibly.
class BlockingPercentProgressDialog extends StatelessWidget {
  const BlockingPercentProgressDialog({
    super.key,
    required this.progress,
    required this.message,
  });

  /// 0.0–1.0.
  final double progress;

  /// Already-localized line under the indicator.
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = verseImageGenerationPercent(progress);

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 92,
                width: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 92,
                      width: 92,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    Text(
                      context.t(
                        'ui.studio.verse_images_progress_percent',
                        parameters: {'percent': percent},
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
