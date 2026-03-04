import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';

extension AppTextContext on BuildContext {
  String t(String key, {required String fallback}) {
    try {
      final container = ProviderScope.containerOf(this, listen: false);
      return container.read(textContentProvider).get(key, fallback: fallback);
    } catch (_) {
      return fallback;
    }
  }
}
