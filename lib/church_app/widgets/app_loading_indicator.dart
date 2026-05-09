import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 112,
    this.label,
  });

  final double size;
  final String? label;

  static const assetPath = 'assets/lottie/app_loader.lottie';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelText = label?.trim();

    return Semantics(
      label: labelText == null || labelText.isEmpty ? 'Loading' : labelText,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: size,
            child: Lottie.asset(
              assetPath,
              repeat: true,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: SizedBox.square(
                    dimension: size * 0.32,
                    child: CircularProgressIndicator(
                      strokeWidth: size < 80 ? 2 : 3,
                    ),
                  ),
                );
              },
            ),
          ),
          if (labelText != null && labelText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              labelText,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
