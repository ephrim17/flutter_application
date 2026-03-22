import 'package:flutter/material.dart';

class ColorText extends StatelessWidget {
  const ColorText({
    super.key,
    required this.badgeText,
    this.fontSize,
  });

  final String badgeText;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      badgeText,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary
      ),
    );
  }
}