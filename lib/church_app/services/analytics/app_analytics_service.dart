import 'package:firebase_analytics/firebase_analytics.dart';

class AppAnalyticsEvent {
  static const dashboardOpened = 'dashboard_opened';
  static const membersChartModeChanged = 'members_chart_mode_changed';
  static const membersChartSegmentSelected = 'members_chart_segment_selected';
  static const forgotPasswordRequested = 'forgot_password_requested';
  static const superAdminDashboardOpened = 'super_admin_dashboard_opened';
  static const churchCreatedSuperAdmin = 'church_created_super_admin';
  static const churchStatusChanged = 'church_status_changed';
}

class AppAnalyticsService {
  const AppAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    final sanitized = <String, Object>{};
    parameters.forEach((key, value) {
      if (value == null) return;
      if (value is String || value is num || value is bool) {
        sanitized[key] = value;
      } else {
        sanitized[key] = value.toString();
      }
    });

    await _analytics.logEvent(
      name: name,
      parameters: sanitized.isEmpty ? null : sanitized,
    );
  }
}
