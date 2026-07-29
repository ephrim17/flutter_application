import 'package:flutter/material.dart';

class FeedScrollNavigation extends StatelessWidget {
  const FeedScrollNavigation({
    super.key,
    required this.controller,
    required this.latestLabel,
    required this.olderLabel,
  });

  final ScrollController controller;
  final String latestLabel;
  final String olderLabel;

  Future<void> _moveTo(bool latest) async {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    final target = latest ? position.minScrollExtent : position.maxScrollExtent;
    final distance = (position.pixels - target).abs();
    if (distance < 1) return;

    await controller.animateTo(
      target,
      duration: Duration(
        milliseconds: (260 + distance * 0.12).clamp(260, 650).round(),
      ),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final position = controller.hasClients ? controller.position : null;
        final showLatest = position != null &&
            position.hasContentDimensions &&
            position.pixels > position.minScrollExtent + 120;
        final label = showLatest ? latestLabel : olderLabel;
        final icon = showLatest
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded;

        return Material(
          elevation: 5,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _moveTo(showLatest),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 5),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
