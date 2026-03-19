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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withAlpha(topOpacity),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: child,
    );
  }
}
