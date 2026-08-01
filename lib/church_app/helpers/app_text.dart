import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';

extension AppTextContext on BuildContext {
  String t(
    String key, {
    String? fallback,
    Map<String, Object?> parameters = const {},
  }) {
    try {
      final container = ProviderScope.containerOf(this, listen: false);
      return container.read(textContentProvider).get(
            key,
            fallback: fallback,
            parameters: parameters,
          );
    } catch (_) {
      return TextContent.fromMap(null).get(
        key,
        fallback: fallback,
        parameters: parameters,
      );
    }
  }
}
