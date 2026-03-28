import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
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
    final expiringPrayers = _expiringPrayers(prayers);
    final recentJoinCount = recentMembers
        .where(
          (member) =>
              member.createdAt != null &&
              DateTime.now().difference(member.createdAt!).inDays <= 7,
        )
        .length;
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
          _ExecutiveDashboardGrid(
            attentionNow: _SectionCard(
              title: 'What Needs Attention Now',
              subtitle: 'The items that need an admin response right away.',
              child: _AttentionNowPanel(
                pendingMembers: pendingMembers,
                expiringPrayers: expiringPrayers,
                announcements: announcements,
                events: events,
              ),
            ),
            recentChanges: _SectionCard(
              title: 'What Changed Recently',
              subtitle: 'Fresh movement across members, updates, and events.',
              child: _RecentChangesPanel(
                recentMembers: recentMembers,
                recentJoinCount: recentJoinCount,
              ),
            ),
            healthSignals: _SectionCard(
              title: 'Church Insights',
              subtitle:
                  'A quick read on approvals, engagement, and content readiness.',
              child: _HealthSignalsPanel(
                metrics: metrics,
                announcements: announcements,
                events: events,
                expiringPrayers: expiringPrayers,
              ),
            ),
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
          _SectionCard(
            title: 'Members Joined Since Recorded',
            subtitle:
                'A quick read on membership growth since church records began.',
            child: _MemberJoinHistory(
              members: members,
            ),
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
                if (index < 0 || index >= groups.length) {
                  return;
                }
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

class _MemberJoinHistory extends StatelessWidget {
  const _MemberJoinHistory({
    required this.members,
  });

  final List<AppUser> members;

  @override
  Widget build(BuildContext context) {
    final datedMembers = members
        .where((member) => member.createdAt != null)
        .toList(growable: false)
      ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

    if (datedMembers.isEmpty) {
      return const _EmptyState(
        title: 'No membership history yet',
        subtitle:
            'Once member records include join dates, growth insights will appear here.',
      );
    }

    final firstRecorded = datedMembers.first.createdAt!;
    final totalRecorded = datedMembers.length;
    final joinedLast30 = datedMembers
        .where(
          (member) => DateTime.now().difference(member.createdAt!).inDays <= 30,
        )
        .length;
    final joinedLast90 = datedMembers
        .where(
          (member) => DateTime.now().difference(member.createdAt!).inDays <= 90,
        )
        .length;
    final joinedThisYear = datedMembers
        .where((member) => member.createdAt!.year == DateTime.now().year)
        .length;

    return Column(
      children: [
        _SignalTile(
          title: 'Records began',
          value: _dateLabelVerbose(firstRecorded),
          tone: _SignalTone.healthy,
          caption:
              '$totalRecorded members have been recorded since this date.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniMetricTile(
                label: 'Last 30 days',
                value: joinedLast30.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniMetricTile(
                label: 'Last 90 days',
                value: joinedLast90.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SimpleStatRow(
          label: 'Joined this year',
          value: '$joinedThisYear members',
        ),
      ],
    );
  }
}

class _ExecutiveDashboardGrid extends StatelessWidget {
  const _ExecutiveDashboardGrid({
    required this.attentionNow,
    required this.recentChanges,
    required this.healthSignals,
  });

  final Widget attentionNow;
  final Widget recentChanges;
  final Widget healthSignals;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;

        if (!isWide) {
          return Column(
            children: [
              attentionNow,
              const SizedBox(height: 18),
              recentChanges,
              const SizedBox(height: 18),
              healthSignals,
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: attentionNow),
                const SizedBox(width: 18),
                Expanded(child: recentChanges),
              ],
            ),
            const SizedBox(height: 18),
            healthSignals,
          ],
        );
      },
    );
  }
}

class _AttentionNowPanel extends StatelessWidget {
  const _AttentionNowPanel({
    required this.pendingMembers,
    required this.expiringPrayers,
    required this.announcements,
    required this.events,
  });

  final List<AppUser> pendingMembers;
  final List<PrayerRequest> expiringPrayers;
  final List<Announcement> announcements;
  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SignalTile(
          title: 'Pending approvals',
          value: pendingMembers.length.toString(),
          tone: pendingMembers.isEmpty
              ? _SignalTone.healthy
              : _SignalTone.attention,
          caption: pendingMembers.isEmpty
              ? 'No one is waiting for review.'
              : 'Members are waiting for an admin decision.',
        ),
        const SizedBox(height: 12),
        _SignalTile(
          title: 'Prayers expiring this week',
          value: expiringPrayers.length.toString(),
          tone: expiringPrayers.isEmpty
              ? _SignalTone.healthy
              : _SignalTone.attention,
          caption: expiringPrayers.isEmpty
              ? 'Nothing urgent is about to expire.'
              : 'Prayer follow-up may be needed soon.',
        ),
        const SizedBox(height: 12),
        _SignalTile(
          title: 'Content gaps',
          value: _contentGapCount(announcements, events).toString(),
          tone: _contentGapCount(announcements, events) == 0
              ? _SignalTone.healthy
              : _SignalTone.warning,
          caption: _contentGapCount(announcements, events) == 0
              ? 'Announcements and events are both live.'
              : 'One or more public-facing sections feel empty.',
        ),
      ],
    );
  }
}

class _RecentChangesPanel extends StatelessWidget {
  const _RecentChangesPanel({
    required this.recentMembers,
    required this.recentJoinCount,
  });

  final List<AppUser> recentMembers;
  final int recentJoinCount;

  @override
  Widget build(BuildContext context) {
    final latestMembers = recentMembers.take(3).toList(growable: false);

    return Column(
      children: [
        _SignalTile(
          title: 'Recent joins this week',
          value: recentJoinCount.toString(),
          tone:
              recentJoinCount == 0 ? _SignalTone.warning : _SignalTone.healthy,
          caption: recentJoinCount == 0
              ? 'No newly added members in the last 7 days.'
              : 'Fresh movement is happening in the church directory.',
        ),
        if (latestMembers.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...List.generate(latestMembers.length, (index) {
            final member = latestMembers[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index == latestMembers.length - 1 ? 0 : 12),
              child: _SimpleStatRow(
                label:
                    'Member ${index + 1}: ${member.name.trim().isEmpty ? 'Member' : member.name}',
                value: member.approved ? 'Approved' : 'Pending',
              ),
            );
          }),
        ] else ...[
          const SizedBox(height: 12),
          const _SimpleStatRow(
            label: 'Recent members',
            value: 'No change',
          ),
        ],
      ],
    );
  }
}

class _HealthSignalsPanel extends StatelessWidget {
  const _HealthSignalsPanel({
    required this.metrics,
    required this.announcements,
    required this.events,
    required this.expiringPrayers,
  });

  final _DashboardMetrics metrics;
  final List<Announcement> announcements;
  final List<Event> events;
  final List<PrayerRequest> expiringPrayers;

  @override
  Widget build(BuildContext context) {
    final approvalRate = metrics.memberCount == 0
        ? 100
        : ((metrics.approvedMembers / metrics.memberCount) * 100).round();

    return Column(
      children: [
        _HealthRow(
          label: 'Approval health',
          value: '$approvalRate%',
          healthy: metrics.pendingApprovals <= 2,
        ),
        const SizedBox(height: 10),
        _HealthRow(
          label: 'Group participation',
          value: '${metrics.groupParticipationRate}%',
          healthy: metrics.groupParticipationRate >= 50,
        ),
        const SizedBox(height: 10),
        _HealthRow(
          label: 'Content readiness',
          value: '${announcements.length + events.length} live',
          healthy: announcements.isNotEmpty && events.isNotEmpty,
        ),
        const SizedBox(height: 10),
        _HealthRow(
          label: 'Prayer urgency',
          value: '${expiringPrayers.length} urgent',
          healthy: expiringPrayers.length <= 2,
        ),
      ],
    );
  }
}

enum _SignalTone {
  healthy,
  warning,
  attention,
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({
    required this.title,
    required this.value,
    required this.tone,
    required this.caption,
  });

  final String title;
  final String value;
  final _SignalTone tone;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (tone) {
      _SignalTone.healthy => Colors.green,
      _SignalTone.warning => Colors.orange,
      _SignalTone.attention => theme.colorScheme.primary,
    };
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: onSurface.withValues(alpha: 0.76),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.value,
    required this.healthy,
  });

  final String label;
  final String value;
  final bool healthy;

  @override
  Widget build(BuildContext context) {
    final color = healthy ? Colors.green : Colors.orange;
    final status = healthy ? 'Healthy' : 'Needs attention';
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}


enum _MemberChartMode {
  gender('Gender', 'Distribution by profile gender.'),
  age('Age', 'A quick view of age buckets across the church.'),
  family('Family', 'How members are split by family category.'),
  solemnized(
    'Solemnized',
    'A quick view of baptism records across the church.',
  );

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
                  if (index == null || index < 0 || index >= groups.length) {
                    return;
                  }
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

class _SelectedGroupDetails extends StatefulWidget {
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
  State<_SelectedGroupDetails> createState() => _SelectedGroupDetailsState();
}

class _SelectedGroupDetailsState extends State<_SelectedGroupDetails> {
  String? _selectedFamilyId;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final percentage = widget.total == 0
        ? 0
        : ((widget.group.count / widget.total) * 100).round();
    final showFamilyDrilldown = widget.mode == _MemberChartMode.family &&
        widget.group.label == 'Family';
    final families = showFamilyDrilldown
        ? _groupFamiliesForDashboard(widget.group.members)
        : const <_FamilyBucket>[];
    final topFamilies =
        families.take(5).toList(growable: false);
    _FamilyBucket? selectedFamily;
    if (_selectedFamilyId != null) {
      for (final family in families) {
        if (family.id == _selectedFamilyId) {
          selectedFamily = family;
          break;
        }
      }
    }

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
                  color: widget.group.color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.group.label,
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
            '${widget.group.count} members in this ${widget.mode.label.toLowerCase()} segment',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: onSurface.withValues(alpha: 0.76),
                ),
          ),
          const SizedBox(height: 14),
          if (widget.group.members.isEmpty)
            const _EmptyState(
              title: 'No matching members',
              subtitle:
                  'Once profiles are updated, matching members will appear here.',
            )
          else if (showFamilyDrilldown)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Families',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 10),
                ...topFamilies.map(
                  (family) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SimpleStatRow(
                      label: family.label,
                      value: '${family.members.length} members',
                      selected: family.id == _selectedFamilyId,
                      onTap: () {
                        setState(() {
                          _selectedFamilyId = family.id == _selectedFamilyId
                              ? null
                              : family.id;
                        });
                      },
                    ),
                  ),
                ),
                if (families.length > topFamilies.length) ...[
                  const SizedBox(height: 2),
                  _SimpleStatRow(
                    label: '+ ${families.length - topFamilies.length} more families',
                    value: 'View all',
                    onTap: () async {
                      final selected = await _showFamilyDirectorySheet(
                        context,
                        families,
                      );
                      if (!mounted || selected == null) return;
                      setState(() {
                        _selectedFamilyId = selected.id;
                      });
                    },
                  ),
                ],
                if (selectedFamily != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Members in ${selectedFamily.label}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...selectedFamily.members.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SimpleStatRow(
                        label:
                            member.name.trim().isEmpty ? 'Member' : member.name,
                        value: member.maritalStatus.trim().isEmpty
                            ? 'Family member'
                            : _formatDashboardCategory(member.maritalStatus),
                      ),
                    ),
                  ),
                ],
              ],
            )
          else
            ...widget.group.members.take(5).map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SimpleStatRow(
                      label:
                          member.name.trim().isEmpty ? 'Member' : member.name,
                      value: _memberSecondaryLabel(member, widget.mode),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

Future<_FamilyBucket?> _showFamilyDirectorySheet(
  BuildContext context,
  List<_FamilyBucket> families,
) {
  var query = '';
  return showModalBottomSheet<_FamilyBucket>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final filteredFamilies = families.where((family) {
            final q = query.trim().toLowerCase();
            if (q.isEmpty) return true;
            return family.label.toLowerCase().contains(q);
          }).toList(growable: false);

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Families',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) {
                      setModalState(() {
                        query = value;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search families',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: filteredFamilies.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No families match this search.'),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredFamilies.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final family = filteredFamilies[index];
                              return _SimpleStatRow(
                                label: family.label,
                                value: '${family.members.length} members',
                                onTap: () =>
                                    Navigator.of(context).pop(family),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _SimpleStatRow extends StatelessWidget {
  const _SimpleStatRow({
    required this.label,
    required this.value,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.4)
              : Theme.of(context)
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
      ),
    );
  }
}

class _FamilyBucket {
  const _FamilyBucket({
    required this.id,
    required this.label,
    required this.members,
  });

  final String id;
  final String label;
  final List<AppUser> members;
}

class _MiniMetricTile extends StatelessWidget {
  const _MiniMetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
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
                trailing: '',
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

List<PrayerRequest> _expiringPrayers(List<PrayerRequest> prayers) {
  final now = DateTime.now();
  final cutoff = now.add(const Duration(days: 7));
  return prayers
      .where(
        (prayer) =>
            !prayer.expiryDate.isBefore(now) &&
            !prayer.expiryDate.isAfter(cutoff),
      )
      .toList(growable: false);
}

int _contentGapCount(
  List<Announcement> announcements,
  List<Event> events,
) {
  var gaps = 0;
  if (announcements.isEmpty) gaps += 1;
  if (events.isEmpty) gaps += 1;
  return gaps;
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
    case _MemberChartMode.solemnized:
      return _groupFromBuckets(
        members,
        {
          'Solemnized': (
            Colors.blue,
            (AppUser member) => member.solemnizedBaptism,
          ),
          'Not solemnized': (
            Colors.orange,
            (AppUser member) => !member.solemnizedBaptism,
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

List<_FamilyBucket> _groupFamiliesForDashboard(List<AppUser> members) {
  final grouped = <String, List<AppUser>>{};

  for (final member in members) {
    final familyId = member.familyId.trim().isEmpty
        ? 'unknown_family'
        : member.familyId.trim();
    grouped.putIfAbsent(familyId, () => []).add(member);
  }

  final buckets = grouped.entries
      .map(
        (entry) => _FamilyBucket(
          id: entry.key,
          label: _formatDashboardFamilyLabel(entry.key),
          members: [...entry.value]
            ..sort(
              (a, b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            ),
        ),
      )
      .toList()
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  return buckets;
}

String _formatDashboardFamilyLabel(String familyId) {
  final normalized = familyId.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'unknown_family') {
    return 'Unknown family';
  }

  var cleaned = normalized
      .replaceFirst(RegExp(r'^family_'), '')
      .replaceFirst(RegExp(r'^individual_'), '');

  final parts = cleaned.split('_').where((part) => part.isNotEmpty).toList();
  if (parts.length > 1) {
    parts.removeLast();
  }

  final displayName = parts
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ')
      .trim();

  if (displayName.isEmpty) {
    return 'Unknown family';
  }

  final suffix = displayName.endsWith('s') ? "'" : "'s";
  return '$displayName$suffix family';
}

String _formatDashboardCategory(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'Not provided';
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
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
    case _MemberChartMode.solemnized:
      if (!member.solemnizedBaptism) {
        return 'No baptism record yet';
      }
      final churchName = member.baptismChurchName.trim();
      if (churchName.isNotEmpty) {
        return churchName;
      }
      return 'Baptism recorded';
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

String _dateLabelVerbose(DateTime value) {
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
  return '${value.day} $month ${value.year}';
}
