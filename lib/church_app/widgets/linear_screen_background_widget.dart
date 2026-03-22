import 'package:flutter/material.dart';

class LinearScreenBackground extends StatelessWidget {
  const LinearScreenBackground({
    super.key,
    required this.child,
    this.topOpacity = 28,
    this.solidBackground = false,
  });

  final Widget child;
  final int topOpacity;
  final bool solidBackground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useSolidBackground = solidBackground;

    return Container(
      decoration: BoxDecoration(
        color: useSolidBackground ? theme.scaffoldBackgroundColor : null,
        gradient: useSolidBackground
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
