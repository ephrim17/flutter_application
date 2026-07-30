import 'package:flutter/material.dart';

class AppCountBadge extends StatelessWidget {
  const AppCountBadge({
    super.key,
    required this.count,
    this.semanticLabel,
  });

  final int count;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final displayCount = count > 999 ? '999+' : '$count';

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticLabel == null
          ? displayCount
          : '$semanticLabel: $displayCount',
      child: SizedBox(
        width: 30,
        child: Text(
          displayCount,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.78),
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
