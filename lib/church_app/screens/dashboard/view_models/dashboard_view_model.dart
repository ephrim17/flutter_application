import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_application/church_app/models/dashboard_member_metrics_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/announcement_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/dashboard/dashboard_providers.dart';
import 'package:flutter_application/church_app/screens/dashboard/view_models/dashboard_view_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardViewModelProvider =
    AsyncNotifierProvider<DashboardViewModel, DashboardViewState>(
  DashboardViewModel.new,
);

class DashboardViewModel extends AsyncNotifier<DashboardViewState> {
  bool _hasLoggedOpen = false;

  @override
  Future<DashboardViewState> build() async {
    final previous = state.value;
    const title = 'Church';
    final isAdmin = ref.watch(isAdminProvider);

    if (!isAdmin) {
      return DashboardViewState.accessDenied(
        churchTitle: title,
        selectedChartMode:
            previous?.selectedChartMode ?? DashboardMemberChartMode.gender,
      );
    }

    final churchId = await ref.watch(currentChurchIdProvider.future);
    await _logDashboardOpen(churchId);

    final results = await Future.wait<Object>([
      ref.watch(dashboardMemberMetricsProvider.future),
      ref.watch(dashboardPrayerRequestsProvider.future),
      ref.watch(dashboardAnnouncementsProvider.future),
      ref.watch(dashboardEventsProvider.future),
      ref.watch(dashboardAppConfigProvider.future),
    ]);

    final nextState = DashboardViewState(
      isAdmin: true,
      churchTitle: title,
      churchId: churchId,
      memberMetrics: results[0] as DashboardMemberMetrics,
      prayers: results[1] as List<PrayerRequest>,
      announcements: results[2] as List<Announcement>,
      events: results[3] as List<Event>,
      admins: (results[4] as dynamic).admins as List<String>,
      selectedChartMode:
          previous?.selectedChartMode ?? DashboardMemberChartMode.gender,
      selectedChartIndex: previous?.selectedChartIndex ?? 0,
    );

    return nextState.normalized();
  }

  Future<void> refresh() async {
    ref.invalidate(dashboardMemberMetricsProvider);
    ref.invalidate(dashboardPrayerRequestsProvider);
    ref.invalidate(dashboardAnnouncementsProvider);
    ref.invalidate(dashboardEventsProvider);
    ref.invalidate(dashboardAppConfigProvider);
    ref.invalidateSelf();
    await future;
  }

  Future<void> selectChartMode(DashboardMemberChartMode mode) async {
    final current = state.value;
    if (current == null) return;
    await _logChartInteraction(
      churchId: current.churchId,
      mode: mode,
      segment: null,
    );
    state = AsyncData(
      current.copyWith(
        selectedChartMode: mode,
        selectedChartIndex: 0,
      ),
    );
  }

  Future<void> selectChartSegment(int index) async {
    final current = state.value;
    if (current == null) return;
    final groups = current.memberGroups;
    if (index < 0 || index >= groups.length) return;
    await _logChartInteraction(
      churchId: current.churchId,
      mode: current.selectedChartMode,
      segment: groups[index].label,
    );
    state = AsyncData(current.copyWith(selectedChartIndex: index));
  }

  Future<void> _logDashboardOpen(String? churchId) async {
    if (_hasLoggedOpen) return;
    _hasLoggedOpen = true;
    await FirebaseAnalytics.instance.logEvent(
      name: 'dashboard_opened',
      parameters: {
        if (churchId != null && churchId.trim().isNotEmpty)
          'church_id': churchId,
      },
    );
  }

  Future<void> _logChartInteraction({
    required String? churchId,
    required DashboardMemberChartMode mode,
    required String? segment,
  }) {
    return FirebaseAnalytics.instance.logEvent(
      name: segment == null
          ? 'members_chart_mode_changed'
          : 'members_chart_segment_selected',
      parameters: {
        if (churchId != null && churchId.trim().isNotEmpty)
          'church_id': churchId,
        'mode': mode.name,
        if (segment != null) 'segment': segment,
      },
    );
  }
}
