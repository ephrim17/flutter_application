import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> logAnalyticsEvent({
  required String name,
  Map<String, Object?> parameters = const {},
}) {
  return FirebaseAnalytics.instance.logEvent(
    name: name,
    parameters: _sanitizeAnalyticsParameters(parameters),
  );
}

Future<void> logChurchAnalyticsEvent(
  WidgetRef ref, {
  required String name,
  Map<String, Object?> parameters = const {},
}) async {
  final churchId = await ref.read(currentChurchIdProvider.future);
  final merged = <String, Object?>{
    if (churchId != null && churchId.trim().isNotEmpty) 'church_id': churchId,
    ...parameters,
  };

  await FirebaseAnalytics.instance.logEvent(
    name: name,
    parameters: _sanitizeAnalyticsParameters(merged),
  );
}

Map<String, Object> _sanitizeAnalyticsParameters(Map<String, Object?> raw) {
  final result = <String, Object>{};

  for (final entry in raw.entries) {
    final value = entry.value;
    if (value == null) continue;

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      result[entry.key] = trimmed;
      continue;
    }

    if (value is bool) {
      result[entry.key] = value.toString();
      continue;
    }

    if (value is num) {
      result[entry.key] = value;
    }
  }

  return result;
}
