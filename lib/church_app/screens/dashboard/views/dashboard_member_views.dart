part of 'package:flutter_application/church_app/screens/dashboard/dashboard_screen.dart';

class _DashboardMemberInsightsSection extends ConsumerWidget {
  const _DashboardMemberInsightsSection({
    required this.state,
    required this.members,
  });

  final DashboardViewState state;
  final List<ChurchMembership> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = state.memberGroups;
    final safeIndex = state.selectedChartSafeIndex;
    final total = groups.fold<int>(0, (sum, item) => sum + item.count);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: DashboardMemberChartMode.values
              .map(
                (mode) => _DashboardModeChip(
                  label: context.t(mode.labelKey),
                  selected: state.selectedChartMode == mode,
                  onTap: () => ref
                      .read(dashboardViewModelProvider.notifier)
                      .selectChartMode(mode),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final chart = _DashboardDonutChart(
              groups: groups,
              total: total,
              selectedIndex: safeIndex,
              onSectionTap: (index) {
                ref
                    .read(dashboardViewModelProvider.notifier)
                    .selectChartSegment(index);
              },
            );
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(state.selectedChartMode.descriptionKey),
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
                    child: _DashboardLegendTile(
                      group: group,
                      total: total,
                      selected: index == safeIndex,
                      // Tapping highlights the segment, nothing more. No
                      // view drills into a member list — the snapshot is
                      // the chart and its legend.
                      onTap: () => ref
                          .read(dashboardViewModelProvider.notifier)
                          .selectChartSegment(index),
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
        // The chart and its legend are the whole snapshot: each segment's
        // colour, label, count and share. What used to sit below this — a
        // per-segment panel listing families and member names — repeated
        // what the legend already says and buried the chart.
      ],
    );
  }
}

class _DashboardModeChip extends StatelessWidget {
  const _DashboardModeChip({
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

class _DashboardDonutChart extends StatelessWidget {
  const _DashboardDonutChart({
    required this.groups,
    required this.total,
    required this.selectedIndex,
    required this.onSectionTap,
  });

  final List<DashboardMemberGroup> groups;
  final int total;
  final int selectedIndex;
  final ValueChanged<int> onSectionTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    if (groups.isEmpty || total == 0) {
      return _DashboardEmptyState(
        title: context.t('dashboard.no_chart_data'),
        subtitle: context.t('dashboard.no_chart_data_hint'),
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
                context.t('dashboard.members'),
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

class _DashboardLegendTile extends StatelessWidget {
  const _DashboardLegendTile({
    required this.group,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final DashboardMemberGroup group;
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
                context.t(group.labelKey),
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
