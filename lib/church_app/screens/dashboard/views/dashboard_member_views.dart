part of 'package:flutter_application/church_app/screens/dashboard/dashboard_screen.dart';

class _DashboardMemberInsightsSection extends ConsumerWidget {
  const _DashboardMemberInsightsSection({
    required this.state,
  });

  final DashboardViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = state.memberGroups;
    final safeIndex = state.selectedChartSafeIndex;
    final selectedGroup = state.selectedMemberGroup;
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
                  label: mode.label,
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
                  state.selectedChartMode.description,
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
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: selectedGroup == null
              ? const _DashboardEmptyState(
                  title: 'No member insights yet',
                  subtitle:
                      'As member profiles are completed, interactive insights will show up here.',
                )
              : _DashboardSelectedGroupDetails(
                  key: ValueKey(
                    '${state.selectedChartMode.name}-${selectedGroup.label}',
                  ),
                  mode: state.selectedChartMode,
                  group: selectedGroup,
                  total: total,
                  summary: state.memberMetrics,
                ),
        ),
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
      return const _DashboardEmptyState(
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

class _DashboardSelectedGroupDetails extends ConsumerStatefulWidget {
  const _DashboardSelectedGroupDetails({
    super.key,
    required this.mode,
    required this.group,
    required this.total,
    required this.summary,
  });

  final DashboardMemberChartMode mode;
  final DashboardMemberGroup group;
  final int total;
  final DashboardMemberMetrics summary;

  @override
  ConsumerState<_DashboardSelectedGroupDetails> createState() =>
      _DashboardSelectedGroupDetailsState();
}

class _DashboardSelectedGroupDetailsState
    extends ConsumerState<_DashboardSelectedGroupDetails> {
  String? _selectedFamilyId;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final percentage = widget.total == 0
        ? 0
        : ((widget.group.count / widget.total) * 100).round();
    final showFamilyDrilldown =
        widget.mode == DashboardMemberChartMode.family &&
            widget.group.label == 'Family';
    final families = showFamilyDrilldown
        ? widget.summary.familyBuckets
        : const <DashboardFamilyBucket>[];
    final topFamilies = families.take(5).toList(growable: false);
    DashboardFamilyBucket? selectedFamily;
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
          if (widget.group.count == 0)
            const _DashboardEmptyState(
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
                    child: _DashboardStatRow(
                      label: family.label,
                      value: '${family.count} members',
                      selected: family.id == _selectedFamilyId,
                      onTap: () {
                        setState(() {
                          _selectedFamilyId =
                              family.id == _selectedFamilyId ? null : family.id;
                        });
                      },
                    ),
                  ),
                ),
                if (families.length > topFamilies.length) ...[
                  const SizedBox(height: 2),
                  _DashboardStatRow(
                    label:
                        '+ ${families.length - topFamilies.length} more families',
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
                  Consumer(
                    builder: (context, ref, _) {
                      final familyMembersAsync = ref.watch(
                        dashboardFamilyMembersProvider(selectedFamily!),
                      );
                      return familyMembersAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (_, __) => const _DashboardEmptyState(
                          title: 'Unable to load family members',
                          subtitle:
                              'Try refreshing the dashboard to load this family again.',
                        ),
                        data: (familyMembers) {
                          if (familyMembers.isEmpty) {
                            return const _DashboardEmptyState(
                              title: 'No family members found',
                              subtitle:
                                  'No members are currently linked to this family.',
                            );
                          }
                          return Column(
                            children: familyMembers
                                .map(
                                  (member) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _DashboardStatRow(
                                      label: member.name.trim().isEmpty
                                          ? 'Member'
                                          : member.name,
                                      value: member.maritalStatus.trim().isEmpty
                                          ? 'Family member'
                                          : formatDashboardCategory(
                                              member.maritalStatus,
                                            ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          );
                        },
                      );
                    },
                  ),
                ],
              ],
            )
          else
            ...widget.group.previewMembers.take(5).map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DashboardStatRow(
                      label:
                          member.name.trim().isEmpty ? 'Member' : member.name,
                      value: member.secondary.trim().isEmpty
                          ? 'Member'
                          : member.secondary,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

Future<DashboardFamilyBucket?> _showFamilyDirectorySheet(
  BuildContext context,
  List<DashboardFamilyBucket> families,
) {
  var query = '';
  return showModalBottomSheet<DashboardFamilyBucket>(
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
                  AppTextField(
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
                              return _DashboardStatRow(
                                label: family.label,
                                value: '${family.count} members',
                                onTap: () => Navigator.of(context).pop(family),
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
