part of '../dashboard_screen.dart';

bool _isSameDashboardDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

class _DashboardFaithMetric extends StatelessWidget {
  const _DashboardFaithMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      );
}

class _DashboardFaithLoopUpdatesSection extends StatelessWidget {
  const _DashboardFaithLoopUpdatesSection({
    required this.updatesAsync,
    required this.members,
  });

  final AsyncValue<FaithLoopDashboardUpdate> updatesAsync;
  final List<AppUser> members;

  @override
  Widget build(BuildContext context) => updatesAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (_, __) => _DashboardEmptyState(
          title: context.t('dashboard.faith_loop_failed'),
          subtitle: context.t('dashboard.faith_loop_failed_hint'),
        ),
        data: (updates) {
          if (updates.records.isEmpty) {
            return _DashboardEmptyState(
              title: context.t('dashboard.faith_loop_empty'),
              subtitle: context.t('dashboard.faith_loop_empty_hint'),
            );
          }
          final now = DateTime.now();
          final today = updates.recordsForDay(now);
          final completed = today.where((record) => record.isComplete).length;
          final completionRate =
              today.isEmpty ? 0 : (completed / today.length * 100).round();
          final reflectCount = today
              .where((record) => record.completedSteps.contains('reflect'))
              .length;
          final prayerCount = today
              .where((record) => record.completedSteps.contains('pray'))
              .length;
          final actionCount = today
              .where((record) => record.completedSteps.contains('challenge'))
              .length;
          final history = List.generate(7, (index) {
            final day = DateTime(now.year, now.month, now.day)
                .subtract(Duration(days: 6 - index));
            return (day: day, completed: updates.completedForDay(day));
          });
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DashboardFaithMetric(
                      label: context.t('dashboard.faith_loop_started'),
                      value: '${today.length}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DashboardFaithMetric(
                      label: context.t('dashboard.faith_loop_completed'),
                      value: '$completed',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DashboardFaithMetric(
                      label: context.t('dashboard.faith_loop_rate'),
                      value: '$completionRate%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('dashboard.faith_loop_steps_today'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    _FaithLoopStepProgress(
                      label: context.t('faith.reflect_step'),
                      count: reflectCount,
                      total: today.length,
                    ),
                    const SizedBox(height: 8),
                    _FaithLoopStepProgress(
                      label: context.t('faith.pray_step'),
                      count: prayerCount,
                      total: today.length,
                    ),
                    const SizedBox(height: 8),
                    _FaithLoopStepProgress(
                      label: context.t('faith.challenge_step'),
                      count: actionCount,
                      total: today.length,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.t('dashboard.faith_loop_seven_day_history'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final isToday = _isSameDashboardDay(item.day, now);
                    return Container(
                      width: 62,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isToday
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isToday
                                ? context.t('dashboard.today_short')
                                : DateFormat.E().format(item.day),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: isToday
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : null,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.completed}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: isToday
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : null,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: today.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _FaithLoopMemberProgressScreen(
                                records: today,
                                members: members,
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.people_outline_rounded),
                  label: Text(
                    context.t('dashboard.faith_loop_view_members'),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _FaithLoopStepProgress extends StatelessWidget {
  const _FaithLoopStepProgress({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label)),
          SizedBox(
            width: 90,
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : count / total,
              minHeight: 7,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      );
}

class _FaithLoopMemberProgressScreen extends StatelessWidget {
  const _FaithLoopMemberProgressScreen({
    required this.records,
    required this.members,
  });

  final List<DailyFaithProgressRecord> records;
  final List<AppUser> members;

  @override
  Widget build(BuildContext context) {
    final membersById = {for (final member in members) member.uid: member};
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('dashboard.faith_loop_member_progress')),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final record = records[index];
          final member = membersById[record.userId];
          final name = member?.name.trim().isNotEmpty == true
              ? member!.name
              : context.t('dashboard.unknown_member');
          return Container(
            decoration: carouselBoxDecoration(context),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: AppProfileAvatar(
                name: name,
                imageUrl: member?.profilePhotoUrl,
                radius: 22,
              ),
              title: Text(name),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _FaithLoopStepChip(
                      label: context.t('dashboard.faith_loop_reflect'),
                      completed: record.completedSteps.contains('reflect'),
                    ),
                    _FaithLoopStepChip(
                      label: context.t('dashboard.faith_loop_prayer'),
                      completed: record.completedSteps.contains('pray'),
                    ),
                    _FaithLoopStepChip(
                      label: context.t('dashboard.faith_loop_action'),
                      completed: record.completedSteps.contains('challenge'),
                    ),
                  ],
                ),
              ),
              trailing: Icon(
                record.isComplete
                    ? Icons.check_circle_rounded
                    : Icons.timelapse_rounded,
                color: record.isComplete ? Colors.green : Colors.orange,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FaithLoopStepChip extends StatelessWidget {
  const _FaithLoopStepChip({required this.label, required this.completed});

  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) => Chip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(
          completed ? Icons.check_rounded : Icons.remove_rounded,
          size: 16,
        ),
        label: Text(label),
      );
}
