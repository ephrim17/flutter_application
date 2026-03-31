part of 'package:flutter_application/church_app/screens/dashboard/dashboard_screen.dart';

class _DashboardHeroSection extends StatelessWidget {
  const _DashboardHeroSection({
    required this.churchTitle,
    required this.metrics,
    required this.isLoading,
  });

  final String churchTitle;
  final DashboardOverviewMetrics metrics;
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
              _DashboardHeroChip(
                icon: Icons.groups_2_outlined,
                label: '${metrics.approvedMembers} approved',
              ),
              _DashboardHeroChip(
                icon: Icons.favorite_border_rounded,
                label: '${metrics.prayerCount} active prayers',
              ),
              _DashboardHeroChip(
                icon: Icons.campaign_outlined,
                label: '${metrics.announcementCount} announcements',
              ),
              _DashboardHeroChip(
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

class _DashboardHeroChip extends StatelessWidget {
  const _DashboardHeroChip({
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

class _DashboardSectionCard extends StatelessWidget {
  const _DashboardSectionCard({
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

class _DashboardMemberJoinHistory extends StatelessWidget {
  const _DashboardMemberJoinHistory({
    required this.summary,
  });

  final DashboardMemberMetrics summary;

  @override
  Widget build(BuildContext context) {
    if (summary.memberCount == 0 || summary.firstRecordedAt == null) {
      return const _DashboardEmptyState(
        title: 'No membership history yet',
        subtitle:
            'Once member records include join dates, growth insights will appear here.',
      );
    }

    return Column(
      children: [
        _DashboardSignalTile(
          title: 'Records began',
          value: _dateLabelVerbose(summary.firstRecordedAt!),
          tone: _SignalTone.healthy,
          caption:
              '${summary.memberCount} members have been recorded since this date.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DashboardMiniMetricTile(
                label: 'Last 30 days',
                value: summary.recentJoinCount30d.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardMiniMetricTile(
                label: 'Last 90 days',
                value: summary.recentJoinCount90d.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DashboardStatRow(
          label: 'Joined this year',
          value: '${summary.joinedThisYear} members',
        ),
      ],
    );
  }
}

class _DashboardExecutiveGrid extends StatelessWidget {
  const _DashboardExecutiveGrid({
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

class _DashboardAttentionPanel extends StatelessWidget {
  const _DashboardAttentionPanel({
    required this.pendingApprovals,
    required this.expiringPrayers,
    required this.announcements,
    required this.events,
  });

  final int pendingApprovals;
  final List<PrayerRequest> expiringPrayers;
  final List<Announcement> announcements;
  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    final contentGapCount =
        (announcements.isEmpty ? 1 : 0) + (events.isEmpty ? 1 : 0);
    return Column(
      children: [
        _DashboardSignalTile(
          title: 'Pending approvals',
          value: pendingApprovals.toString(),
          tone: pendingApprovals == 0
              ? _SignalTone.healthy
              : _SignalTone.attention,
          caption: pendingApprovals == 0
              ? 'No one is waiting for review.'
              : 'Members are waiting for an admin decision.',
        ),
        const SizedBox(height: 12),
        _DashboardSignalTile(
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
        _DashboardSignalTile(
          title: 'Content gaps',
          value: contentGapCount.toString(),
          tone:
              contentGapCount == 0 ? _SignalTone.healthy : _SignalTone.warning,
          caption: contentGapCount == 0
              ? 'Announcements and events are both live.'
              : 'One or more public-facing sections feel empty.',
        ),
      ],
    );
  }
}

class _DashboardRecentChangesPanel extends StatelessWidget {
  const _DashboardRecentChangesPanel({
    required this.recentMembers,
    required this.recentJoinCount,
  });

  final List<DashboardPreviewMember> recentMembers;
  final int recentJoinCount;

  @override
  Widget build(BuildContext context) {
    final latestMembers = recentMembers.take(3).toList(growable: false);

    return Column(
      children: [
        _DashboardSignalTile(
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
              padding: EdgeInsets.only(
                  bottom: index == latestMembers.length - 1 ? 0 : 12),
              child: _DashboardStatRow(
                label:
                    'Member ${index + 1}: ${member.name.trim().isEmpty ? 'Member' : member.name}',
                value: member.approved ? 'Approved' : 'Pending',
              ),
            );
          }),
        ] else ...[
          const SizedBox(height: 12),
          const _DashboardStatRow(
            label: 'Recent members',
            value: 'No change',
          ),
        ],
      ],
    );
  }
}

class _DashboardHealthSignalsPanel extends StatelessWidget {
  const _DashboardHealthSignalsPanel({
    required this.state,
  });

  final DashboardViewState state;

  @override
  Widget build(BuildContext context) {
    final approvalRate = state.metrics.memberCount == 0
        ? 100
        : ((state.metrics.approvedMembers / state.metrics.memberCount) * 100)
            .round();

    return Column(
      children: [
        _DashboardHealthRow(
          label: 'Approval health',
          value: '$approvalRate%',
          healthy: state.metrics.pendingApprovals <= 2,
        ),
        const SizedBox(height: 10),
        _DashboardHealthRow(
          label: 'Group participation',
          value: '${state.metrics.groupParticipationRate}%',
          healthy: state.metrics.groupParticipationRate >= 50,
        ),
        const SizedBox(height: 10),
        _DashboardHealthRow(
          label: 'Content readiness',
          value: '${state.announcements.length + state.events.length} live',
          healthy: state.announcements.isNotEmpty && state.events.isNotEmpty,
        ),
        const SizedBox(height: 10),
        _DashboardHealthRow(
          label: 'Prayer urgency',
          value: '${state.expiringPrayers.length} urgent',
          healthy: state.expiringPrayers.length <= 2,
        ),
      ],
    );
  }
}

class _DashboardMemberStreakPanel extends StatelessWidget {
  const _DashboardMemberStreakPanel({
    required this.summary,
  });

  final DashboardMemberMetrics summary;

  @override
  Widget build(BuildContext context) {
    if (summary.memberCount == 0) {
      return const _DashboardEmptyState(
        title: 'No streak data yet',
        subtitle:
            'As members begin using the app, daily streak insights will show here.',
      );
    }

    return Column(
      children: [
        _DashboardSignalTile(
          title: 'Members on a streak',
          value: '${summary.activeStreakMembersCount}',
          tone: summary.activeStreakMembersCount == 0
              ? _SignalTone.warning
              : _SignalTone.healthy,
          caption: summary.activeStreakMembersCount == 0
              ? 'No member has started a daily streak yet.'
              : '${summary.activeStreakRate}% of members currently have an active streak.',
        ),
        const SizedBox(height: 12),
        _DashboardSignalTile(
          title: 'Strong consistency',
          value: '${summary.membersWith7PlusCount}',
          tone: summary.membersWith7PlusCount == 0
              ? _SignalTone.warning
              : _SignalTone.healthy,
          caption: summary.membersWith7PlusCount == 0
              ? 'No member has crossed a 7-day streak yet.'
              : '${summary.membersWith7PlusCount} member${summary.membersWith7PlusCount == 1 ? '' : 's'} have built a 7+ day rhythm.',
        ),
        const SizedBox(height: 12),
        _DashboardSignalTile(
          title: 'Current streak leader',
          value: summary.topStreakMember == null
              ? 'No streak yet'
              : '${summary.topStreakValue} days',
          tone: summary.topStreakMember == null
              ? _SignalTone.warning
              : _SignalTone.attention,
          caption: summary.topStreakMember == null
              ? 'Once a member starts a streak, the top streak will show here.'
              : '${summary.topStreakMember!.name.trim().isEmpty ? 'A member' : summary.topStreakMember!.name} is leading the church right now.',
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

class _DashboardSignalTile extends StatelessWidget {
  const _DashboardSignalTile({
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

class _DashboardHealthRow extends StatelessWidget {
  const _DashboardHealthRow({
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

class _DashboardStatRow extends StatelessWidget {
  const _DashboardStatRow({
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

class _DashboardMiniMetricTile extends StatelessWidget {
  const _DashboardMiniMetricTile({
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
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
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

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({
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
