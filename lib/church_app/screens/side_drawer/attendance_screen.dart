import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/widgets/desktop_content_width.dart';
import 'package:flutter_application/church_app/helpers/attendance_stats.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/attendance_service_model.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/providers/members_provider.dart';
import 'package:flutter_application/church_app/providers/side_drawer/attendance_providers.dart';
import 'package:flutter_application/church_app/screens/side_drawer/attendance_mark_screen.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/modals/attendance_service_form.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The display name of a service type, falling back to the stored key if a
/// church has an older or unknown value on a document.
String attendanceServiceTypeLabel(BuildContext context, String typeKey) {
  final key = typeKey.trim();
  if (key.isEmpty) return '';
  return context.t('attendance.service_type.$key', fallback: key);
}

/// Members the attendance screen counts as the expected roster: approved,
/// church-scoped people. The percentage and the absence streak are measured
/// against this, never against everyone who has ever been marked present.
List<ChurchMembership> attendanceRoster(List<ChurchMembership> members) {
  return members.where((member) => member.approved).toList(growable: false)
    ..sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
}

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  static final _dayFormat = DateFormat('d');
  static final _monthFormat = DateFormat('MMM yy');

  /// Empty means every type.
  String _typeFilter = '';

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(attendanceServicesProvider);
    final membersAsync = ref.watch(membersProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(text: context.t('attendance.screen_title')),
      ),
      body: servicesAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (_, __) => _LoadFailed(
          onRetry: () => ref.invalidate(attendanceServicesProvider),
        ),
        data: (services) {
          final roster =
              attendanceRoster(membersAsync.asData?.value ?? const []);
          final summary = attendanceSummary(
            services: services,
            activeMemberIds: roster.map((member) => member.docId).toSet(),
          );
          final visible = _typeFilter.isEmpty
              ? sortAttendanceServices(services)
              : sortAttendanceServices(services)
                  .where((service) => service.type == _typeFilter)
                  .toList(growable: false);

          return DesktopContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _SummaryGrid(summary: summary),
                if (services.length >= 2) ...[
                  const SizedBox(height: 18),
                  _TrendChart(services: services),
                ],
                const SizedBox(height: 18),
                _TypeFilter(
                  value: _typeFilter,
                  onChanged: (value) => setState(() => _typeFilter = value),
                ),
                const SizedBox(height: 12),
                if (services.isEmpty)
                  _EmptyState(onRecord: () => _recordService(context))
                else
                  for (final service in visible) ...[
                    _ServiceTile(
                      service: service,
                      rosterSize: roster.length,
                      dayFormat: _dayFormat,
                      monthFormat: _monthFormat,
                      onTap: () => _openService(service.id),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _recordService(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.t('attendance.record_service')),
      ),
    );
  }

  Future<void> _recordService(BuildContext context) async {
    final serviceId = await showAppModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AttendanceServiceForm(),
    );
    if (serviceId == null || !mounted) return;
    // Straight into marking: recording a service and marking who came is one
    // task, and a church does it with people still in the room.
    await _openService(serviceId);
  }

  Future<void> _openService(String serviceId) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceMarkScreen(serviceId: serviceId),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    String value(int? number, {String suffix = ''}) =>
        number == null ? '—' : '$number$suffix';

    final boxes = [
      _StatBox(
        value: value(summary.lastServicePresent),
        label: context.t('attendance.stat_last'),
      ),
      _StatBox(
        value: value(summary.averagePresent),
        label: context.t('attendance.stat_average'),
      ),
      _StatBox(
        value: value(summary.lastServicePercent, suffix: '%'),
        label: context.t('attendance.stat_percent'),
      ),
      _StatBox(
        value: summary.isEmpty ? '—' : '${summary.absentCount}',
        label: context.t('attendance.stat_absent'),
        highlight: summary.absentCount > 0,
      ),
    ];

    // The column count follows the width, and the tile height is fixed
    // rather than an aspect ratio. Two fixed columns at a 1.75 ratio gave
    // each tile about 770 by 440 on a desktop window — an enormous box
    // around the word "16", with the number stranded in one corner.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = statGridColumns(
          constraints.maxWidth,
          itemCount: boxes.length,
        );

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: (constraints.maxWidth - (columns - 1) * 10) /
              columns /
              statGridTileHeight(columns),
          children: boxes,
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: carouselBoxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: highlight ? colors.error : colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// A plain bar per service. Deliberately not a charting dependency: twelve
/// bars and a label do not justify one.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.services});

  final List<AttendanceService> services;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bars = attendanceTrendServices(services);
    final peak = bars.fold<int>(
      1,
      (max, service) =>
          service.present.length > max ? service.present.length : max,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: carouselBoxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('attendance.trend_title'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            context.t('attendance.trend_hint'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 128,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < bars.length; index++)
                  Expanded(
                    child: _TrendBar(
                      service: bars[index],
                      peak: peak,
                      isLatest: index == bars.length - 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.service,
    required this.peak,
    required this.isLatest,
  });

  final AttendanceService service;
  final int peak;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final count = service.present.length;
    // A zero-attendance service still gets a sliver of bar, so the date
    // label underneath belongs to something visible.
    final fraction = peak == 0 ? 0.0 : count / peak;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$count',
            style: theme.textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Flexible(
            child: FractionallySizedBox(
              heightFactor: fraction.clamp(0.04, 1.0),
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: isLatest
                      ? colors.primary
                      : colors.primary.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            DateFormat('d/M').format(service.date),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: context.t('attendance.filter_all_types'),
            selected: value.isEmpty,
            onTap: () => onChanged(''),
          ),
          for (final key in attendanceServiceTypeKeys) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: attendanceServiceTypeLabel(context, key),
              selected: value == key,
              onTap: () => onChanged(key),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.rosterSize,
    required this.dayFormat,
    required this.monthFormat,
    required this.onTap,
  });

  final AttendanceService service;
  final int rosterSize;
  final DateFormat dayFormat;
  final DateFormat monthFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final present = service.present.length;
    final extras = <String>[
      if (service.visitorCount > 0)
        context.t(
          'attendance.visitors_suffix',
          parameters: {'count': service.visitorCount},
        ),
      if (service.childrenCount > 0)
        context.t(
          'attendance.children_suffix',
          parameters: {'count': service.childrenCount},
        ),
      if (service.notes.isNotEmpty) service.notes,
    ];

    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.72),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      dayFormat.format(service.date),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      monthFormat.format(service.date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attendanceServiceTypeLabel(context, service.type),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    // The church's own name for this gathering, directly
                    // under the type it qualifies — it is what tells the
                    // 1st, 2nd and 3rd Sunday worship of one date apart.
                    if (service.subheader.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        service.subheader,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (extras.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        extras.join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$present',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    rosterSize == 0
                        ? context.t(
                            'attendance.present_count',
                            parameters: {'count': present},
                          )
                        : context.t(
                            'attendance.percent_of_active',
                            parameters: {
                              'percent': (present / rosterSize * 100).round(),
                            },
                          ),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the register cannot be read at all.
///
/// The usual cause is `firestore.rules` not carrying the `services` match
/// yet — the feature's rules are deployed separately from the app binary, so
/// a build can reach a backend that has never heard of this collection. An
/// endless spinner would leave an admin waiting on something that is never
/// going to arrive.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              context.t('attendance.load_failed'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.t('feed.retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRecord});

  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      decoration: carouselBoxDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.fact_check_outlined,
            size: 44,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            context.t('attendance.empty_title'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('attendance.empty_hint'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRecord,
            icon: const Icon(Icons.add_rounded),
            label: Text(context.t('attendance.record_service')),
          ),
        ],
      ),
    );
  }
}
