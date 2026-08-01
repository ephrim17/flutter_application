import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/dashboard_member_metrics_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/announcement_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/dashboard/dashboard_providers.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/for_you_section_config_providers.dart';
import 'package:flutter_application/church_app/providers/home_sections/home_section_config_providers.dart';
import 'package:flutter_application/church_app/screens/dashboard/dashboard_gender_members_screen.dart';
import 'package:flutter_application/church_app/screens/dashboard/view_models/dashboard_view_model.dart';
import 'package:flutter_application/church_app/screens/dashboard/view_models/dashboard_view_state.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/app_profile_avatar.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/disabled_feature_tips.dart';
import 'package:flutter_application/church_app/widgets/modals/today_birthdays_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

part 'views/dashboard_overview_views.dart';
part 'views/dashboard_member_views.dart';
part 'views/dashboard_quick_look_views.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardStateAsync = ref.watch(dashboardViewModelProvider);
    final dashboardMembersAsync = ref.watch(dashboardMembersProvider);
    final homeSectionConfigsAsync = ref.watch(homeSectionConfigsProvider);
    final forYouSectionConfigsAsync = ref.watch(forYouSectionConfigsProvider);
    final homeSectionConfigs =
        homeSectionConfigsAsync.asData?.value ?? const [];
    final forYouSectionConfigs =
        forYouSectionConfigsAsync.asData?.value ?? const [];
    final sectionConfigsLoaded =
        homeSectionConfigsAsync.hasValue && forYouSectionConfigsAsync.hasValue;
    final dashboardState = dashboardStateAsync.value ??
        DashboardViewState.accessDenied(
          churchTitle: context.t('dashboard.church_fallback'),
          selectedChartMode: DashboardMemberChartMode.gender,
        );

    if (!dashboardState.isAdmin) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: carouselBoxDecoration(context),
          child: Text(
            context.t('dashboard.admin_only'),
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
    final anniversaryMembers = dashboardMembers
        .where((member) => isAnniversaryToday(member.weddingDay))
        .toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    bool homeSectionDisabled(String id) => !(homeSectionConfigs
            .where((config) => config.id == id)
            .firstOrNull
            ?.enabled ??
        false);
    bool forYouSectionDisabled(String id) => !(forYouSectionConfigs
            .where((config) => config.id == id)
            .firstOrNull
            ?.enabled ??
        false);
    final disabledFeatureTips = <DisabledFeatureTip>[
      if (homeSectionDisabled('announcements'))
        DisabledFeatureTip(
          title: context.t('dashboard.feature_announcements'),
          icon: Icons.campaign_outlined,
        ),
      if (homeSectionDisabled('events'))
        DisabledFeatureTip(
          title: context.t('dashboard.feature_events'),
          icon: Icons.event_outlined,
        ),
      if (homeSectionDisabled('promise'))
        DisabledFeatureTip(
          title: context.t('dashboard.feature_promise'),
          icon: Icons.wb_sunny_outlined,
        ),
      if (forYouSectionDisabled('liveChurch'))
        DisabledFeatureTip(
          title: context.t('dashboard.feature_live_church'),
          icon: Icons.live_tv_outlined,
        ),
      if (forYouSectionDisabled('dailyVerse'))
        DisabledFeatureTip(
          title: context.t('dashboard.feature_daily_verse'),
          icon: Icons.menu_book_outlined,
        ),
      if (forYouSectionDisabled('featured'))
        DisabledFeatureTip(
          title: context.t('dashboard.feature_featured'),
          icon: Icons.star_outline_rounded,
        ),
      if (forYouSectionDisabled('article'))
        DisabledFeatureTip(
          title: context.t('dashboard.feature_articles'),
          icon: Icons.article_outlined,
        ),
    ];
    if (!sectionConfigsLoaded) disabledFeatureTips.clear();
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
          if (disabledFeatureTips.isNotEmpty) ...[
            const SizedBox(height: 18),
            _DashboardSectionCard(
              title: context.t('dashboard.features_disabled_title'),
              subtitle: context.t('dashboard.features_disabled_subtitle'),
              child: DisabledFeatureTips(tips: disabledFeatureTips),
            ),
          ],
          const SizedBox(height: 18),
          _DashboardSectionCard(
            title: context.t('dashboard.special_days_title'),
            subtitle: context.t('dashboard.special_days_subtitle'),
            child: _DashboardSpecialDaysSection(
              birthdays: birthdayMembers,
              anniversaries: anniversaryMembers,
            ),
          ),
          const SizedBox(height: 18),
          _DashboardSectionCard(
            title: context.t('dashboard.insights_title'),
            subtitle: context.t('dashboard.insights_subtitle'),
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
                  title: context.t('dashboard.members_snapshot_title'),
                  subtitle: context.t('dashboard.members_snapshot_subtitle'),
                  child: _DashboardMemberInsightsSection(
                    state: dashboardState,
                    members: dashboardMembers,
                  ),
                );
              }

              return _DashboardSectionCard(
                title: context.t('dashboard.members_snapshot_title'),
                subtitle: context.t('dashboard.members_snapshot_subtitle'),
                child: _DashboardMemberInsightsSection(
                  state: dashboardState,
                  members: dashboardMembers,
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          _DashboardSectionCard(
            title: context.t('dashboard.join_history_title'),
            subtitle: context.t('dashboard.join_history_subtitle'),
            child: _DashboardMemberJoinHistory(
              summary: dashboardState.memberMetrics,
            ),
          ),
          const SizedBox(height: 18),
          _DashboardSectionCard(
            title: context.t('dashboard.streaks_title'),
            subtitle: context.t('dashboard.streaks_subtitle'),
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
                  title: context.t('dashboard.prayer_pulse_title'),
                  subtitle: context.t('dashboard.prayer_pulse_subtitle'),
                  child: _DashboardPrayerQuickLook(
                    prayers: dashboardState.prayers,
                    isLoading: dashboardStateAsync.isLoading,
                  ),
                ),
              ];
              final rightColumn = [
                _DashboardSectionCard(
                  title: context.t('dashboard.announcements_title'),
                  subtitle: context.t('dashboard.announcements_subtitle'),
                  child: _DashboardAnnouncementQuickLook(
                    announcements: dashboardState.announcements,
                    isLoading: dashboardStateAsync.isLoading,
                  ),
                ),
                const SizedBox(height: 18),
                _DashboardSectionCard(
                  title: context.t('dashboard.events_title'),
                  subtitle: context.t('dashboard.events_subtitle'),
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
