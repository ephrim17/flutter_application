import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/dashboard_member_metrics_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/announcement_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/dashboard/dashboard_providers.dart';
import 'package:flutter_application/church_app/screens/dashboard/view_models/dashboard_view_model.dart';
import 'package:flutter_application/church_app/screens/dashboard/view_models/dashboard_view_state.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/modals/today_birthdays_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'views/dashboard_overview_views.dart';
part 'views/dashboard_member_views.dart';
part 'views/dashboard_quick_look_views.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardStateAsync = ref.watch(dashboardViewModelProvider);
    final dashboardMembersAsync = ref.watch(dashboardMembersProvider);
    final dashboardState = dashboardStateAsync.value ??
        DashboardViewState.accessDenied(
          churchTitle: 'Church',
          selectedChartMode: DashboardMemberChartMode.gender,
        );

    if (!dashboardState.isAdmin) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: carouselBoxDecoration(context),
          child: Text(
            'Dashboard is available only for admins.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final dashboardMembers =
        dashboardMembersAsync.asData?.value ?? const <AppUser>[];
    final birthdayMembers =
        dashboardMembers.where((member) => isBirthdayToday(member.dob)).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return RefreshIndicator(
      onRefresh: () => ref.read(dashboardViewModelProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _DashboardHeroSection(
            churchTitle: dashboardState.churchTitle,
            metrics: dashboardState.metrics,
            isLoading: dashboardStateAsync.isLoading,
          ),
          const SizedBox(height: 18),
          _DashboardSectionCard(
            title: "Today's Birthdays",
            subtitle:
                'Celebrate members today and jump straight into a birthday post.',
            child: _DashboardBirthdaySection(
              members: birthdayMembers,
            ),
          ),
          const SizedBox(height: 18),
          _DashboardSectionCard(
            title: 'Church Insights',
            subtitle:
                'A quick read on approvals, engagement, content readiness, and recent movement.',
            child: _DashboardHealthSignalsPanel(
              state: dashboardState,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;
              if (!isWide) {
                return _DashboardSectionCard(
                  title: 'Members Snapshot',
                  subtitle: 'Approved, pending, families, and ministry reach.',
                  child: _DashboardMemberInsightsSection(
                    state: dashboardState,
                  ),
                );
              }

              return _DashboardSectionCard(
                title: 'Members Snapshot',
                subtitle: 'Approved, pending, families, and ministry reach.',
                child: _DashboardMemberInsightsSection(
                  state: dashboardState,
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          _DashboardSectionCard(
            title: 'Members Joined Since Recorded',
            subtitle:
                'A quick read on membership growth since church records began.',
            child: _DashboardMemberJoinHistory(
              summary: dashboardState.memberMetrics,
            ),
          ),
          const SizedBox(height: 18),
          _DashboardSectionCard(
            title: 'Daily Streaks',
            subtitle:
                'See which members are showing up consistently across the app.',
            child: _DashboardMemberStreakPanel(
              summary: dashboardState.memberMetrics,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;
              final leftColumn = [
                _DashboardSectionCard(
                  title: 'Prayer Pulse',
                  subtitle:
                      'Current requests that need attention or follow-up.',
                  child: _DashboardPrayerQuickLook(
                    prayers: dashboardState.prayers,
                    isLoading: dashboardStateAsync.isLoading,
                  ),
                ),
              ];
              final rightColumn = [
                _DashboardSectionCard(
                  title: 'Announcements',
                  subtitle:
                      'Active communication visible across the church app.',
                  child: _DashboardAnnouncementQuickLook(
                    announcements: dashboardState.announcements,
                    isLoading: dashboardStateAsync.isLoading,
                  ),
                ),
                const SizedBox(height: 18),
                _DashboardSectionCard(
                  title: 'Events',
                  subtitle:
                      'Upcoming items and current engagement opportunities.',
                  child: _DashboardEventQuickLook(
                    events: dashboardState.events,
                    isLoading: dashboardStateAsync.isLoading,
                  ),
                ),
              ];

              if (!isWide) {
                return Column(
                  children: [
                    ...leftColumn,
                    const SizedBox(height: 18),
                    ...rightColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: leftColumn,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      children: rightColumn,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
