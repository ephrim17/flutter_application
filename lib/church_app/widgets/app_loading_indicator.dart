import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 112,
    this.label,
  });

  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelText = label?.trim();
    final semanticsLabel = labelText == null || labelText.isEmpty
        ? context.t('common.loading')
        : labelText;

    return Semantics(
      label: semanticsLabel,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: size,
            child: _FallbackLoader(size: size),
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

class _FallbackLoader extends StatelessWidget {
  const _FallbackLoader({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: size * 0.32,
        child: CircularProgressIndicator(
          strokeWidth: size < 80 ? 2 : 3,
        ),
      ),
    );
  }
}
