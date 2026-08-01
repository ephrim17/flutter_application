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
    final onPrimary = theme.colorScheme.onPrimary;
    final secondaryText = onPrimary.withValues(alpha: 0.88);
    return Container(
      decoration: welcomeBackCardDecoration(context),
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
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 16,
                      color: onPrimary.withValues(alpha: 0.95),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.t('dashboard.admin_title'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: onPrimary.withValues(alpha: 0.96),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            churchTitle.trim().isEmpty
                ? context.t('dashboard.church_fallback')
                : churchTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: onPrimary,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.t('dashboard.hero_subtitle'),
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
                label: context.t(
                  'dashboard.approved_count',
                  parameters: {'count': metrics.approvedMembers},
                ),
              ),
              _DashboardHeroChip(
                icon: Icons.favorite_border_rounded,
                label: context.t(
                  'dashboard.active_prayers_count',
                  parameters: {'count': metrics.prayerCount},
                ),
              ),
              _DashboardHeroChip(
                icon: Icons.campaign_outlined,
                label: context.t(
                  'dashboard.announcements_count',
                  parameters: {'count': metrics.announcementCount},
                ),
              ),
              _DashboardHeroChip(
                icon: Icons.event_available_outlined,
                label: context.t(
                  'dashboard.events_count',
                  parameters: {'count': metrics.eventCount},
                ),
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
    final textColor = theme.colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
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

class _DashboardSpecialDaysSection extends StatelessWidget {
  const _DashboardSpecialDaysSection({
    required this.birthdays,
    required this.anniversaries,
  });

  final List<AppUser> birthdays;
  final List<AppUser> anniversaries;

  @override
  Widget build(BuildContext context) {
    if (birthdays.isEmpty && anniversaries.isEmpty) {
      return _DashboardEmptyState(
        title: context.t('dashboard.no_special_days'),
        subtitle: context.t('dashboard.no_special_days_hint'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (birthdays.isNotEmpty) ...[
          _DashboardSpecialDayHeading(
            title: context.t('dashboard.birthdays'),
            count: birthdays.length,
          ),
          for (final member in birthdays)
            _DashboardSpecialDayTile(
              member: member,
              type: SpecialPostType.birthday,
              subtitle: _birthdayDashboardLabel(context, member.dob),
            ),
        ],
        if (anniversaries.isNotEmpty) ...[
          if (birthdays.isNotEmpty) const SizedBox(height: 8),
          _DashboardSpecialDayHeading(
            title: context.t('dashboard.wedding_anniversaries'),
            count: anniversaries.length,
          ),
          for (final member in anniversaries)
            _DashboardSpecialDayTile(
              member: member,
              type: SpecialPostType.anniversary,
              subtitle: _anniversaryDashboardLabel(
                context,
                member.weddingDay,
              ),
            ),
        ],
      ],
    );
  }
}

class _DashboardSpecialDayHeading extends StatelessWidget {
  const _DashboardSpecialDayHeading({
    required this.title,
    required this.count,
  });

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: 8),
          Badge(label: Text('$count')),
        ],
      ),
    );
  }
}

class _DashboardSpecialDayTile extends StatelessWidget {
  const _DashboardSpecialDayTile({
    required this.member,
    required this.type,
    required this.subtitle,
  });

  final AppUser member;
  final SpecialPostType type;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: carouselBoxDecoration(context),
      child: ListTile(
        onTap: () {
          showAppModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => FractionallySizedBox(
              heightFactor: 0.95,
              child: BirthdayPostComposerModal(
                member: member,
                type: type,
              ),
            ),
          );
        },
        leading: AppProfileAvatar(
          name: member.name,
          imageUrl: member.profilePhotoUrl,
        ),
        title: Text(member.name),
        subtitle: Text(subtitle),
        trailing: Icon(
          type == SpecialPostType.birthday
              ? Icons.cake_outlined
              : Icons.favorite_outline_rounded,
        ),
      ),
    );
  }
}

String _birthdayDashboardLabel(BuildContext context, DateTime? dob) {
  final age = _dashboardBirthdayAge(dob);
  if (age == null) {
    return context.t('dashboard.birthday_today');
  }
  return context.t(
    'dashboard.turning_age_today',
    parameters: {'age': age},
  );
}

int? _dashboardBirthdayAge(DateTime? dob) {
  if (dob == null) return null;
  final now = DateTime.now();
  return now.year - dob.year;
}

String _anniversaryDashboardLabel(
  BuildContext context,
  DateTime? weddingDay,
) {
  final years = _dashboardBirthdayAge(weddingDay);
  if (years == null) return context.t('dashboard.anniversary_today');
  return context.t(
    'dashboard.anniversary_years_today',
    parameters: {
      'years': years,
      'unit': context.t(
        years == 1 ? 'dashboard.year_singular' : 'dashboard.year_plural',
      ),
    },
  );
}

class _DashboardMemberJoinHistory extends StatelessWidget {
  const _DashboardMemberJoinHistory({
    required this.summary,
  });

  final DashboardMemberMetrics summary;

  @override
  Widget build(BuildContext context) {
    if (summary.memberCount == 0 || summary.firstRecordedAt == null) {
      return _DashboardEmptyState(
        title: context.t('dashboard.no_membership_history'),
        subtitle: context.t('dashboard.no_membership_history_hint'),
      );
    }

    return Column(
      children: [
        _DashboardSignalTile(
          title: context.t('dashboard.records_began'),
          value: _dateLabelVerbose(summary.firstRecordedAt!),
          tone: _SignalTone.healthy,
          caption: context.t(
            'dashboard.members_recorded_since',
            parameters: {'count': summary.memberCount},
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DashboardMiniMetricTile(
                label: context.t('dashboard.last_30_days'),
                value: summary.recentJoinCount30d.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardMiniMetricTile(
                label: context.t('dashboard.last_90_days'),
                value: summary.recentJoinCount90d.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DashboardStatRow(
          label: context.t('dashboard.joined_this_year'),
          value: context.t(
            'dashboard.members_count',
            parameters: {'count': summary.joinedThisYear},
          ),
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
    return Column(
      children: [
        _DashboardSignalTile(
          title: context.t('dashboard.recent_joins_week'),
          value: recentJoinCount.toString(),
          tone:
              recentJoinCount == 0 ? _SignalTone.warning : _SignalTone.healthy,
          caption: recentJoinCount == 0
              ? context.t('dashboard.no_recent_joins')
              : context.t('dashboard.recent_joins_active'),
        ),
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
    return Column(
      children: [
        _DashboardSignalTile(
          title: context.t('dashboard.pending_approvals'),
          value: state.memberMetrics.pendingApprovals.toString(),
          tone: state.memberMetrics.pendingApprovals == 0
              ? _SignalTone.healthy
              : _SignalTone.attention,
          caption: state.memberMetrics.pendingApprovals == 0
              ? context.t('dashboard.no_pending_approvals')
              : context.t('dashboard.pending_approvals_hint'),
        ),
        const SizedBox(height: 12),
        _DashboardSignalTile(
          title: context.t('dashboard.prayers_expiring_week'),
          value: state.expiringPrayers.length.toString(),
          tone: state.expiringPrayers.isEmpty
              ? _SignalTone.healthy
              : _SignalTone.attention,
          caption: state.expiringPrayers.isEmpty
              ? context.t('dashboard.no_expiring_prayers')
              : context.t('dashboard.expiring_prayers_hint'),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            context.t('dashboard.changed_recently'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const SizedBox(height: 12),
        _DashboardRecentChangesPanel(
          recentMembers: state.memberMetrics.recentMembers,
          recentJoinCount: state.memberMetrics.recentJoinCount7d,
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
      return _DashboardEmptyState(
        title: context.t('dashboard.no_streak_data'),
        subtitle: context.t('dashboard.no_streak_data_hint'),
      );
    }

    return Column(
      children: [
        _DashboardSignalTile(
          title: context.t('dashboard.members_on_streak'),
          value: '${summary.activeStreakMembersCount}',
          tone: summary.activeStreakMembersCount == 0
              ? _SignalTone.warning
              : _SignalTone.healthy,
          caption: summary.activeStreakMembersCount == 0
              ? context.t('dashboard.no_active_streak')
              : context.t(
                  'dashboard.active_streak_rate',
                  parameters: {'rate': summary.activeStreakRate},
                ),
        ),
        const SizedBox(height: 12),
        _DashboardSignalTile(
          title: context.t('dashboard.strong_consistency'),
          value: '${summary.membersWith7PlusCount}',
          tone: summary.membersWith7PlusCount == 0
              ? _SignalTone.warning
              : _SignalTone.healthy,
          caption: summary.membersWith7PlusCount == 0
              ? context.t('dashboard.no_strong_streak')
              : context.t(
                  'dashboard.strong_streak_count',
                  parameters: {
                    'count': summary.membersWith7PlusCount,
                    'memberLabel': context.t(
                      summary.membersWith7PlusCount == 1
                          ? 'dashboard.member_singular'
                          : 'dashboard.member_plural',
                    ),
                  },
                ),
        ),
        const SizedBox(height: 12),
        _DashboardSignalTile(
          title: context.t('dashboard.current_streak_leader'),
          value: summary.topStreakMember == null
              ? context.t('dashboard.no_streak_yet')
              : context.t(
                  'dashboard.streak_days',
                  parameters: {'count': summary.topStreakValue},
                ),
          tone: summary.topStreakMember == null
              ? _SignalTone.warning
              : _SignalTone.attention,
          caption: summary.topStreakMember == null
              ? context.t('dashboard.no_streak_leader_hint')
              : context.t(
                  'dashboard.streak_leader_hint',
                  parameters: {
                    'name': summary.topStreakMember!.name.trim().isEmpty
                        ? context.t('dashboard.member_fallback')
                        : summary.topStreakMember!.name,
                  },
                ),
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
  return DateFormat.MMMd().format(value);
}

String _dateLabelVerbose(DateTime value) {
  return DateFormat.yMMMd().format(value);
}
