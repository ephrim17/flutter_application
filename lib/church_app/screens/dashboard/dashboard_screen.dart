import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/church_group_definitions.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/announcement_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/home_sections/announcement_providers.dart';
import 'package:flutter_application/church_app/providers/home_sections/event_providers.dart';
import 'package:flutter_application/church_app/providers/members_provider.dart';
import 'package:flutter_application/church_app/providers/side_drawer/prayer_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final churchId = await ref.read(currentChurchIdProvider.future);
      await FirebaseAnalytics.instance.logEvent(
        name: 'dashboard_opened',
        parameters: {
          if (churchId != null && churchId.trim().isNotEmpty)
            'church_id': churchId,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
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

    final membersAsync = ref.watch(membersProvider);
    final prayersAsync = ref.watch(allPrayerRequestsProvider);
    final announcementsAsync = ref.watch(announcementsProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final configAsync = ref.watch(appConfigProvider);
    final churchId = ref.watch(currentChurchIdProvider).value;
    final title = ref.t('church_tab.app_title', fallback: 'Church');

    final members = membersAsync.value ?? const <AppUser>[];
    final prayers = prayersAsync.value ?? const <PrayerRequest>[];
    final announcements = announcementsAsync.value ?? const <Announcement>[];
    final events = eventsAsync.value ?? const <Event>[];
    final admins = configAsync.value?.admins ?? const <String>[];
    final metrics = _DashboardMetrics.fromData(
      members: members,
      prayers: prayers,
      announcements: announcements,
      events: events,
      admins: admins,
    );

    final isLoading = membersAsync.isLoading ||
        prayersAsync.isLoading ||
        announcementsAsync.isLoading ||
        eventsAsync.isLoading ||
        configAsync.isLoading;
    final recentMembers = [...members]..sort((a, b) =>
        (b.createdAt ?? DateTime(1970))
            .compareTo(a.createdAt ?? DateTime(1970)));
    final pendingMembers =
        members.where((member) => !member.approved).toList(growable: false);
    final upcomingBirthdays = _upcomingBirthdays(members);
    final groupSummaries = _groupSummaries(members);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(membersProvider);
        ref.invalidate(allPrayerRequestsProvider);
        ref.invalidate(announcementsProvider);
        ref.invalidate(eventsProvider);
        ref.invalidate(appConfigProvider);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _DashboardHero(
            churchTitle: title,
            metrics: metrics,
            isLoading: isLoading,
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;
              if (!isWide) {
                return Column(
                  children: [
                    _SectionCard(
                      title: 'Action Center',
                      subtitle:
                          'What needs attention right now across the church.',
                      child: _ActionCenter(
                        pendingMembers: pendingMembers,
                        recentMembers: recentMembers,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionCard(
                      title: 'Church Insights',
                      subtitle:
                          'Participation, ministry reach, and birthday awareness.',
                      child: _ChurchHealthPanel(
                        groupSummaries: groupSummaries,
                        upcomingBirthdays: upcomingBirthdays,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SectionCard(
                      title: 'Action Center',
                      subtitle:
                          'What needs attention right now across the church.',
                      child: _ActionCenter(
                        pendingMembers: pendingMembers,
                        recentMembers: recentMembers,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _SectionCard(
                      title: 'Church Insights',
                      subtitle:
                          'Participation, ministry reach, and birthday awareness.',
                      child: _ChurchHealthPanel(
                        groupSummaries: groupSummaries,
                        upcomingBirthdays: upcomingBirthdays,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;
              if (!isWide) {
                return _SectionCard(
                  title: 'Members Snapshot',
                  subtitle: 'Approved, pending, families, and ministry reach.',
                  child: _MembersInsights(
                    members: members,
                    metrics: metrics,
                    churchId: churchId,
                  ),
                );
              }

              return _SectionCard(
                title: 'Members Snapshot',
                subtitle: 'Approved, pending, families, and ministry reach.',
                child: _MembersInsights(
                  members: members,
                  metrics: metrics,
                  churchId: churchId,
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;
              final leftColumn = [
                _SectionCard(
                  title: 'Prayer Pulse',
                  subtitle:
                      'Current requests that need attention or follow-up.',
                  child: _PrayerQuickLook(
                    prayers: prayers,
                    isLoading: prayersAsync.isLoading,
                  ),
                ),
              ];
              final rightColumn = [
                _SectionCard(
                  title: 'Announcements',
                  subtitle:
                      'Active communication visible across the church app.',
                  child: _AnnouncementQuickLook(
                    announcements: announcements,
                    isLoading: announcementsAsync.isLoading,
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Events',
                  subtitle:
                      'Upcoming items and current engagement opportunities.',
                  child: _EventQuickLook(
                    events: events,
                    isLoading: eventsAsync.isLoading,
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

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.churchTitle,
    required this.metrics,
    required this.isLoading,
  });

  final String churchTitle;
  final _DashboardMetrics metrics;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final secondaryText = onSurface.withValues(alpha: 0.78);
    return Container(
      decoration: carouselBoxDecoration(context).copyWith(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.secondary.withValues(alpha: 0.09),
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Admin Dashboard',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isLoading ? 'Refreshing...' : 'Live church snapshot',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            churchTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A fast pulse on members, prayers, leaders, and the activity shaping church life this week.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: secondaryText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroChip(
                icon: Icons.groups_2_outlined,
                label: '${metrics.approvedMembers} approved',
              ),
              _HeroChip(
                icon: Icons.favorite_border_rounded,
                label: '${metrics.prayerCount} active prayers',
              ),
              _HeroChip(
                icon: Icons.campaign_outlined,
                label: '${metrics.announcementCount} announcements',
              ),
              _HeroChip(
                icon: Icons.event_available_outlined,
                label: '${metrics.eventCount} events',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: carouselBoxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: onSurface.withValues(alpha: 0.78),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _MembersInsights extends StatefulWidget {
  const _MembersInsights({
    required this.members,
    required this.metrics,
    required this.churchId,
  });

  final List<AppUser> members;
  final _DashboardMetrics metrics;
  final String? churchId;

  @override
  State<_MembersInsights> createState() => _MembersInsightsState();
}

class _MembersInsightsState extends State<_MembersInsights> {
  _MemberChartMode _mode = _MemberChartMode.gender;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final groups = _buildMemberGroups(widget.members, _mode);
    final safeIndex =
        groups.isEmpty ? -1 : _selectedIndex.clamp(0, groups.length - 1);
    final selectedGroup = safeIndex >= 0 ? groups[safeIndex] : null;
    final total = groups.fold<int>(0, (sum, item) => sum + item.count);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _MemberChartMode.values
              .map(
                (mode) => _ModeChip(
                  label: mode.label,
                  selected: _mode == mode,
                  onTap: () {
                    FirebaseAnalytics.instance.logEvent(
                      name: 'members_chart_mode_changed',
                      parameters: {
                        if (widget.churchId != null &&
                            widget.churchId!.trim().isNotEmpty)
                          'church_id': widget.churchId!,
                        'mode': mode.name,
                      },
                    );
                    setState(() {
                      _mode = mode;
                      _selectedIndex = 0;
                    });
                  },
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final chart = _InteractiveDonutChart(
              groups: groups,
              total: total,
              selectedIndex: safeIndex,
              onSectionTap: (index) {
                FirebaseAnalytics.instance.logEvent(
                  name: 'members_chart_segment_selected',
                  parameters: {
                    if (widget.churchId != null &&
                        widget.churchId!.trim().isNotEmpty)
                      'church_id': widget.churchId!,
                    'mode': _mode.name,
                    'segment': groups[index].label,
                  },
                );
                setState(() {
                  _selectedIndex = index;
                });
              },
            );
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mode.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: onSurface.withValues(alpha: 0.76),
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 16),
                ...List.generate(groups.length, (index) {
                  final group = groups[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LegendTile(
                      group: group,
                      total: total,
                      selected: index == safeIndex,
                      onTap: () {
                        FirebaseAnalytics.instance.logEvent(
                          name: 'members_chart_segment_selected',
                          parameters: {
                            if (widget.churchId != null &&
                                widget.churchId!.trim().isNotEmpty)
                              'church_id': widget.churchId!,
                            'mode': _mode.name,
                            'segment': group.label,
                          },
                        );
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                    ),
                  );
                }),
              ],
            );

            if (!isWide) {
              return Column(
                children: [
                  chart,
                  const SizedBox(height: 18),
                  details,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: chart),
                const SizedBox(width: 18),
                Expanded(flex: 4, child: details),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: selectedGroup == null
              ? const _EmptyState(
                  title: 'No member insights yet',
                  subtitle:
                      'As member profiles are completed, interactive insights will show up here.',
                )
              : _SelectedGroupDetails(
                  key: ValueKey('${_mode.name}-${selectedGroup.label}'),
                  mode: _mode,
                  group: selectedGroup,
                  total: total,
                ),
        ),
      ],
    );
  }
}

class _ActionCenter extends StatelessWidget {
  const _ActionCenter({
    required this.pendingMembers,
    required this.recentMembers,
  });

  final List<AppUser> pendingMembers;
  final List<AppUser> recentMembers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SubsectionTitle(
          title: 'Pending Approvals',
          subtitle: 'People waiting for an admin decision.',
        ),
        const SizedBox(height: 12),
        if (pendingMembers.isEmpty)
          const _EmptyState(
            title: 'No pending approvals',
            subtitle: 'New signups waiting for review will appear here.',
          )
        else
          ...pendingMembers.take(3).map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MemberMiniTile(
                    member: member,
                    badge: 'Pending',
                  ),
                ),
              ),
        const SizedBox(height: 18),
        _SubsectionTitle(
          title: 'Recent Members',
          subtitle: 'The latest people added to the church directory.',
        ),
        const SizedBox(height: 12),
        if (recentMembers.isEmpty)
          const _EmptyState(
            title: 'No members available',
            subtitle:
                'Newly added members will show up here as activity grows.',
          )
        else
          ...recentMembers.take(4).map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MemberMiniTile(
                    member: member,
                    badge: member.approved ? 'Approved' : 'Pending',
                  ),
                ),
              ),
      ],
    );
  }
}

class _ChurchHealthPanel extends StatelessWidget {
  const _ChurchHealthPanel({
    required this.groupSummaries,
    required this.upcomingBirthdays,
  });

  final List<_GroupSummary> groupSummaries;
  final List<AppUser> upcomingBirthdays;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SubsectionTitle(
          title: 'Group Coverage',
          subtitle: 'A quick look at ministry distribution across groups.',
        ),
        const SizedBox(height: 12),
        if (groupSummaries.isEmpty)
          const _EmptyState(
            title: 'No group activity yet',
            subtitle: 'Members assigned to church groups will show up here.',
          )
        else
          ...groupSummaries.take(4).map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SimpleStatRow(
                    label: group.label,
                    value: group.count.toString(),
                  ),
                ),
              ),
        const SizedBox(height: 18),
        _SubsectionTitle(
          title: 'Upcoming Birthdays',
          subtitle: 'A warm touchpoint for pastoral and admin follow-up.',
        ),
        const SizedBox(height: 12),
        if (upcomingBirthdays.isEmpty)
          const _EmptyState(
            title: 'No birthdays coming up',
            subtitle: 'Members with birthdays in the next 30 days appear here.',
          )
        else
          ...upcomingBirthdays.take(3).map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SimpleStatRow(
                    label: member.name.trim().isEmpty ? 'Member' : member.name,
                    value: _birthdayLabel(member.dob),
                  ),
                ),
              ),
      ],
    );
  }
}

enum _MemberChartMode {
  gender('Gender', 'Distribution by profile gender.'),
  age('Age', 'A quick view of age buckets across the church.'),
  family('Family', 'How members are split by family category.');

  const _MemberChartMode(this.label, this.description);

  final String label;
  final String description;
}

class _MemberGroup {
  const _MemberGroup({
    required this.label,
    required this.color,
    required this.members,
  });

  final String label;
  final Color color;
  final List<AppUser> members;

  int get count => members.length;
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.22)
                : theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.82),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _InteractiveDonutChart extends StatelessWidget {
  const _InteractiveDonutChart({
    required this.groups,
    required this.total,
    required this.selectedIndex,
    required this.onSectionTap,
  });

  final List<_MemberGroup> groups;
  final int total;
  final int selectedIndex;
  final ValueChanged<int> onSectionTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    if (groups.isEmpty || total == 0) {
      return const _EmptyState(
        title: 'No chart data available',
        subtitle: 'Member profile data is needed before this chart can render.',
      );
    }

    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              centerSpaceRadius: 62,
              sectionsSpace: 3,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions) return;
                  final index = response?.touchedSection?.touchedSectionIndex;
                  if (index == null) return;
                  onSectionTap(index);
                },
              ),
              sections: List.generate(groups.length, (index) {
                final group = groups[index];
                final isSelected = index == selectedIndex;
                final percentage =
                    total == 0 ? 0.0 : (group.count / total) * 100;
                return PieChartSectionData(
                  color: group.color,
                  value: group.count.toDouble(),
                  radius: isSelected ? 64 : 54,
                  title: percentage < 8 ? '' : '${percentage.round()}%',
                  titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                );
              }),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                total.toString(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: onSurface,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Members',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onSurface.withValues(alpha: 0.72),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendTile extends StatelessWidget {
  const _LegendTile({
    required this.group,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final _MemberGroup group;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final percentage = total == 0 ? 0 : ((group.count / total) * 100).round();
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? group.color.withValues(alpha: 0.14)
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? group.color.withValues(alpha: 0.34)
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: group.color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                group.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: onSurface,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Text(
              '${group.count} • $percentage%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: onSurface.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedGroupDetails extends StatelessWidget {
  const _SelectedGroupDetails({
    super.key,
    required this.mode,
    required this.group,
    required this.total,
  });

  final _MemberChartMode mode;
  final _MemberGroup group;
  final int total;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final percentage = total == 0 ? 0 : ((group.count / total) * 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: group.color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Text(
                '$percentage%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: onSurface,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${group.count} members in this ${mode.label.toLowerCase()} segment',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: onSurface.withValues(alpha: 0.76),
                ),
          ),
          const SizedBox(height: 14),
          if (group.members.isEmpty)
            const _EmptyState(
              title: 'No matching members',
              subtitle:
                  'Once profiles are updated, matching members will appear here.',
            )
          else
            ...group.members.take(5).map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SimpleStatRow(
                      label:
                          member.name.trim().isEmpty ? 'Member' : member.name,
                      value: _memberSecondaryLabel(member, mode),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _SubsectionTitle extends StatelessWidget {
  const _SubsectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: onSurface.withValues(alpha: 0.74),
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

class _MemberMiniTile extends StatelessWidget {
  const _MemberMiniTile({
    required this.member,
    required this.badge,
  });

  final AppUser member;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final badgeColor = badge == 'Pending' ? Colors.amber : Colors.green;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              member.name.trim().isEmpty
                  ? '?'
                  : member.name.trim()[0].toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: onSurface,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name.trim().isEmpty ? 'Member' : member.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  member.email.trim().isEmpty ? 'No email added' : member.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onSurface.withValues(alpha: 0.76),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: badgeColor.shade700,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleStatRow extends StatelessWidget {
  const _SimpleStatRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: onSurface.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _PrayerQuickLook extends StatelessWidget {
  const _PrayerQuickLook({
    required this.prayers,
    required this.isLoading,
  });

  final List<PrayerRequest> prayers;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final anonymousPrayers =
        prayers.where((prayer) => prayer.isAnonymous).toList(growable: false);

    if (isLoading && prayers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prayers.isEmpty) {
      return const _EmptyState(
        title: 'No active prayers right now',
        subtitle:
            'When requests are submitted, this section will surface them for quick review.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrayerInsightsBanner(
          totalCount: prayers.length,
          anonymousCount: anonymousPrayers.length,
        ),
        const SizedBox(height: 16),
        ...prayers.take(3).map(
              (prayer) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _QuickLookTile(
                  icon: prayer.isAnonymous
                      ? Icons.visibility_off_outlined
                      : Icons.favorite_outline_rounded,
                  title: prayer.title.trim().isEmpty
                      ? 'Prayer Request'
                      : prayer.title,
                  subtitle: prayer.description.trim().isEmpty
                      ? 'No description provided.'
                      : prayer.description,
                  trailing: 'Until ${_dateLabel(prayer.expiryDate)}',
                ),
              ),
            ),
      ],
    );
  }
}

class _PrayerInsightsBanner extends StatelessWidget {
  const _PrayerInsightsBanner({
    required this.totalCount,
    required this.anonymousCount,
  });

  final int totalCount;
  final int anonymousCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_outline_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '$totalCount active requests',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_off_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '$anonymousCount anonymous',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: onSurface.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnnouncementQuickLook extends StatelessWidget {
  const _AnnouncementQuickLook({
    required this.announcements,
    required this.isLoading,
  });

  final List<Announcement> announcements;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && announcements.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (announcements.isEmpty) {
      return const _EmptyState(
        title: 'No active announcements',
        subtitle:
            'Once live announcements are published, they will appear here.',
      );
    }

    return Column(
      children: announcements
          .take(3)
          .map(
            (announcement) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _QuickLookTile(
                icon: Icons.campaign_outlined,
                title: announcement.title.trim().isEmpty
                    ? 'Announcement'
                    : announcement.title,
                subtitle: announcement.body.trim().isEmpty
                    ? 'No announcement body provided.'
                    : announcement.body,
                trailing: 'Priority ${announcement.priority}',
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _EventQuickLook extends StatelessWidget {
  const _EventQuickLook({
    required this.events,
    required this.isLoading,
  });

  final List<Event> events;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (events.isEmpty) {
      return const _EmptyState(
        title: 'No active events',
        subtitle:
            'When events are scheduled, they will show up here as a quick pulse.',
      );
    }

    return Column(
      children: events
          .take(3)
          .map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _QuickLookTile(
                icon: Icons.event_note_rounded,
                title: event.title.trim().isEmpty ? 'Event' : event.title,
                subtitle: event.location.trim().isNotEmpty
                    ? '${event.location} • ${event.timing}'
                    : event.timing,
                trailing: event.type.name,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _QuickLookTile extends StatelessWidget {
  const _QuickLookTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onSurface.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 92),
            child: Text(
              trailing,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: onSurface.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 34,
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: onSurface.withValues(alpha: 0.78),
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetrics {
  const _DashboardMetrics({
    required this.memberCount,
    required this.approvedMembers,
    required this.pendingApprovals,
    required this.familyCount,
    required this.individualCount,
    required this.prayerCount,
    required this.adminCount,
    required this.announcementCount,
    required this.eventCount,
    required this.membersWithGroups,
    required this.groupParticipationRate,
  });

  final int memberCount;
  final int approvedMembers;
  final int pendingApprovals;
  final int familyCount;
  final int individualCount;
  final int prayerCount;
  final int adminCount;
  final int announcementCount;
  final int eventCount;
  final int membersWithGroups;
  final int groupParticipationRate;

  factory _DashboardMetrics.fromData({
    required List<AppUser> members,
    required List<PrayerRequest> prayers,
    required List<Announcement> announcements,
    required List<Event> events,
    required List<String> admins,
  }) {
    final approvedMembers = members.where((member) => member.approved).length;
    final pendingApprovals = members.where((member) => !member.approved).length;
    final familyCount = members
        .where((member) => member.category.trim().toLowerCase() == 'family')
        .length;
    final individualCount = members
        .where((member) => member.category.trim().toLowerCase() != 'family')
        .length;
    final membersWithGroups =
        members.where((member) => member.churchGroupIds.isNotEmpty).length;
    final groupParticipationRate = members.isEmpty
        ? 0
        : ((membersWithGroups / members.length) * 100).round();

    return _DashboardMetrics(
      memberCount: members.length,
      approvedMembers: approvedMembers,
      pendingApprovals: pendingApprovals,
      familyCount: familyCount,
      individualCount: individualCount,
      prayerCount: prayers.length,
      adminCount: admins.length,
      announcementCount: announcements.length,
      eventCount: events.length,
      membersWithGroups: membersWithGroups,
      groupParticipationRate: groupParticipationRate,
    );
  }
}

class _GroupSummary {
  const _GroupSummary({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

List<_GroupSummary> _groupSummaries(List<AppUser> members) {
  final summaries = churchGroupDefinitions.map((group) {
    final count = members
        .where((member) => member.churchGroupIds.contains(group.id))
        .length;
    return _GroupSummary(
      label: group.label,
      count: count,
    );
  }).toList(growable: false);

  summaries.sort((a, b) => b.count.compareTo(a.count));
  return summaries;
}

List<AppUser> _upcomingBirthdays(List<AppUser> members) {
  final now = DateTime.now();
  final withBirthdays =
      members.where((member) => member.dob != null).toList(growable: false);

  final upcoming = withBirthdays.where((member) {
    final dob = member.dob!;
    final next = _nextBirthday(dob, now);
    return next.difference(now).inDays <= 30;
  }).toList();

  upcoming.sort((a, b) {
    final nextA = _nextBirthday(a.dob!, now);
    final nextB = _nextBirthday(b.dob!, now);
    return nextA.compareTo(nextB);
  });

  return upcoming;
}

List<_MemberGroup> _buildMemberGroups(
  List<AppUser> members,
  _MemberChartMode mode,
) {
  switch (mode) {
    case _MemberChartMode.gender:
      return _groupFromBuckets(
        members,
        {
          'Male': (
            Colors.blue,
            (AppUser member) => member.gender.trim().toLowerCase() == 'male',
          ),
          'Female': (
            Colors.pink,
            (AppUser member) => member.gender.trim().toLowerCase() == 'female',
          ),
          'Unknown': (
            Colors.grey,
            (AppUser member) => !{'male', 'female'}
                .contains(member.gender.trim().toLowerCase()),
          ),
        },
      );
    case _MemberChartMode.age:
      return _groupFromBuckets(
        members,
        {
          'Children': (
            Colors.orange,
            (AppUser member) =>
                _ageOf(member.dob) != null && _ageOf(member.dob)! <= 12,
          ),
          'Youth': (
            Colors.purple,
            (AppUser member) {
              final age = _ageOf(member.dob);
              return age != null && age >= 13 && age <= 24;
            },
          ),
          'Adults': (
            Colors.green,
            (AppUser member) {
              final age = _ageOf(member.dob);
              return age != null && age >= 25 && age <= 59;
            },
          ),
          'Seniors': (
            Colors.teal,
            (AppUser member) =>
                _ageOf(member.dob) != null && _ageOf(member.dob)! >= 60,
          ),
          'Unknown': (
            Colors.grey,
            (AppUser member) => _ageOf(member.dob) == null,
          ),
        },
      );
    case _MemberChartMode.family:
      return _groupFromBuckets(
        members,
        {
          'Family': (
            Colors.indigo,
            (AppUser member) =>
                member.category.trim().toLowerCase() == 'family',
          ),
          'Individual': (
            Colors.cyan,
            (AppUser member) =>
                member.category.trim().toLowerCase() == 'individual',
          ),
          'Other': (
            Colors.amber,
            (AppUser member) {
              final category = member.category.trim().toLowerCase();
              return category.isNotEmpty &&
                  category != 'family' &&
                  category != 'individual';
            },
          ),
          'Unspecified': (
            Colors.grey,
            (AppUser member) => member.category.trim().isEmpty,
          ),
        },
      );
  }
}

List<_MemberGroup> _groupFromBuckets(
  List<AppUser> members,
  Map<String, (Color, bool Function(AppUser))> buckets,
) {
  final groups = buckets.entries
      .map((entry) {
        final bucketMembers =
            members.where(entry.value.$2).toList(growable: false);
        return _MemberGroup(
          label: entry.key,
          color: entry.value.$1,
          members: bucketMembers,
        );
      })
      .where((group) => group.count > 0)
      .toList(growable: false);

  return groups;
}

String _memberSecondaryLabel(AppUser member, _MemberChartMode mode) {
  switch (mode) {
    case _MemberChartMode.gender:
      return member.gender.trim().isEmpty
          ? 'Unspecified gender'
          : member.gender;
    case _MemberChartMode.age:
      final age = _ageOf(member.dob);
      return age == null ? 'DOB missing' : '$age years';
    case _MemberChartMode.family:
      return member.category.trim().isEmpty
          ? 'Unspecified category'
          : member.category;
  }
}

int? _ageOf(DateTime? dob) {
  if (dob == null) return null;
  final now = DateTime.now();
  var age = now.year - dob.year;
  final hadBirthday =
      now.month > dob.month || (now.month == dob.month && now.day >= dob.day);
  if (!hadBirthday) age -= 1;
  return age;
}

DateTime _nextBirthday(DateTime dob, DateTime now) {
  var year = now.year;
  var next = DateTime(year, dob.month, dob.day);
  if (next.isBefore(DateTime(now.year, now.month, now.day))) {
    next = DateTime(year + 1, dob.month, dob.day);
  }
  return next;
}

String _dateLabel(DateTime value) {
  final month = switch (value.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
  return '$month ${value.day}';
}

String _birthdayLabel(DateTime? dob) {
  if (dob == null) return '-';
  return _dateLabel(dob);
}
