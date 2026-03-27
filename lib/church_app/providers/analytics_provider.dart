import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_application/church_app/services/analytics/app_analytics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAnalyticsProvider =
    Provider<FirebaseAnalytics>((_) => FirebaseAnalytics.instance);

final firebaseAnalyticsObserverProvider =
    Provider<FirebaseAnalyticsObserver>((ref) {
  return FirebaseAnalyticsObserver(
    analytics: ref.read(firebaseAnalyticsProvider),
  );
});

final appAnalyticsServiceProvider = Provider<AppAnalyticsService>((ref) {
  return AppAnalyticsService(ref.read(firebaseAnalyticsProvider));
});
