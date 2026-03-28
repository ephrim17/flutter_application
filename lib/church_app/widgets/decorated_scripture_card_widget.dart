import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';

class DecoratedScriptureCard extends StatelessWidget {
  const DecoratedScriptureCard({
    super.key,
    required this.width,
    required this.child,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -8,
            top: 22,
            child: _ScriptureAccent(
              icon: Icons.auto_awesome,
              size: 18,
              color: secondary.withValues(alpha: 0.72),
            ),
          ),
          Positioned(
            right: 18,
            top: -12,
            child: _ScriptureAccent(
              icon: Icons.local_florist_outlined,
              size: 24,
              color: primary.withValues(alpha: 0.78),
            ),
          ),
          Positioned(
            right: -8,
            top: 96,
            child: _ScriptureAccent(
              icon: Icons.star_rounded,
              size: 18,
              color: primary.withValues(alpha: 0.62),
            ),
          ),
          Positioned(
            left: 24,
            bottom: -14,
            child: _ScriptureAccent(
              icon: Icons.local_florist,
              size: 20,
              color: secondary.withValues(alpha: 0.68),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: carouselBoxDecoration(context).copyWith(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primary.withValues(alpha: 0.08),
                  secondary.withValues(alpha: 0.05),
                  theme.cardTheme.color ?? Colors.white,
                ],
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class ScriptureReferencePill extends StatelessWidget {
  const ScriptureReferencePill({
    super.key,
    required this.reference,
    this.fontSize = 15,
  });

  final String reference;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        reference,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ScriptureAccent extends StatelessWidget {
  const _ScriptureAccent({
    required this.icon,
    required this.size,
    required this.color,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: icon == Icons.local_florist_outlined ? -0.25 : 0.18,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: size,
          color: color,
        ),
      ),
    );
  }
}
