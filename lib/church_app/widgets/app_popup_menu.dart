import 'package:flutter/material.dart';

class AppPopupMenuAction<T> {
  const AppPopupMenuAction({
    required this.value,
    required this.icon,
    required this.label,
    this.color,
    this.selected = false,
    this.enabled = true,
  });

  final T value;
  final IconData icon;
  final String label;
  final Color? color;
  final bool selected;
  final bool enabled;
}

class AppPopupMenu<T> extends StatelessWidget {
  const AppPopupMenu({
    super.key,
    required this.actions,
    required this.onSelected,
    this.tooltip,
    this.trigger,
    this.minWidth = 210,
  });

  final List<AppPopupMenuAction<T>> actions;
  final ValueChanged<T> onSelected;
  final String? tooltip;
  final Widget? trigger;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return PopupMenuButton<T>(
      tooltip: tooltip ?? MaterialLocalizations.of(context).moreButtonTooltip,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      elevation: 10,
      color: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      constraints: BoxConstraints(minWidth: minWidth),
      icon: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: trigger ?? const Icon(Icons.more_horiz_rounded, size: 20),
      ),
      onSelected: onSelected,
      itemBuilder: (_) => actions
          .map(
            (action) => PopupMenuItem<T>(
              value: action.value,
              enabled: action.enabled,
              child: _AppPopupMenuRow(action: action),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AppPopupMenuRow<T> extends StatelessWidget {
  const _AppPopupMenuRow({required this.action});

  final AppPopupMenuAction<T> action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = action.enabled
        ? action.color ?? theme.colorScheme.onSurface
        : theme.disabledColor;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: foreground.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(action.icon, size: 19, color: foreground),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            action.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (action.selected) ...[
          const SizedBox(width: 12),
          Icon(
            Icons.check_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ],
      ],
    );
  }
}
