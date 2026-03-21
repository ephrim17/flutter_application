import 'package:flutter/material.dart';

class LinearScreenBackground extends StatelessWidget {
  const LinearScreenBackground({
    super.key,
    required this.child,
    this.topOpacity = 28,
  });

  final Widget child;
  final int topOpacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBlackWhitePreflow =
        theme.scaffoldBackgroundColor == Colors.black &&
        theme.colorScheme.primary == Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: isBlackWhitePreflow ? theme.scaffoldBackgroundColor : null,
        gradient: isBlackWhitePreflow
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.primary.withAlpha(topOpacity),
                  theme.scaffoldBackgroundColor,
                ],
              ),
      ),
      child: child,
    );
  }
}
