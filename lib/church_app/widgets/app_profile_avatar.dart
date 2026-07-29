import 'dart:typed_data';

import 'package:flutter/material.dart';

class AppProfileAvatar extends StatelessWidget {
  const AppProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.imageBytes,
    this.radius = 22,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final String name;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    final value = parts.map((part) => part[0].toUpperCase()).join();
    return value.isEmpty ? '?' : value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = radius * 2;
    final fallback = Container(
      width: size,
      height: size,
      color:
          backgroundColor ?? theme.colorScheme.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: theme.textTheme.titleMedium?.copyWith(
          color: foregroundColor ?? theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    Widget content = fallback;
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      content = Image.memory(
        imageBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else if ((imageUrl ?? '').trim().isNotEmpty) {
      content = Image.network(
        imageUrl!.trim(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
