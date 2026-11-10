import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/attendance_stats.dart';
import 'package:flutter_application/church_app/models/attendance_service_model.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/providers/members_provider.dart';
import 'package:flutter_application/church_app/providers/side_drawer/attendance_providers.dart';
import 'package:flutter_application/church_app/screens/side_drawer/attendance_screen.dart'
    show attendanceRoster, attendanceServiceTypeLabel;
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_confirm_dialog.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/app_profile_avatar.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/modals/attendance_service_form.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Tap down the roster, marking who was present.
///
/// The marked set is held locally and written once on Save rather than on
/// every tap: a register is taken in one pass with people still in the room,
/// and a write per tap would be a hundred writes and a hundred chances for a
/// flaky connection to leave the register half-recorded.
class AttendanceMarkScreen extends ConsumerStatefulWidget {
  const AttendanceMarkScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  ConsumerState<AttendanceMarkScreen> createState() =>
      _AttendanceMarkScreenState();
}

enum _RosterFilter { everyone, notMarked }

class _AttendanceMarkScreenState extends ConsumerState<AttendanceMarkScreen> {
  static final _dateFormat = DateFormat('EEEE, d MMM yyyy');

  final _searchController = TextEditingController();

  /// Null until the service's stored list has been loaded once. Seeding on
  /// first load and not on every rebuild is what lets a tap survive the
  /// stream pushing the same document back.
  Set<String>? _present;
  bool _householdMode = true;
  _RosterFilter _filter = _RosterFilter.everyone;
  String _query = '';
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serviceAsync = ref.watch(attendanceServiceProvider(widget.serviceId));
    final membersAsync = ref.watch(membersProvider);

    return serviceAsync.when(
      loading: () => const Scaffold(
        body: Center(child: AppLoadingIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.t('attendance.save_failed'))),
      ),
      data: (service) {
        if (service == null) {
          // Deleted from another device while this screen was open.
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.t('attendance.deleted'))),
          );
        }
        _present ??= service.present.toSet();
        final present = _present!;
        final roster = attendanceRoster(membersAsync.asData?.value ?? const []);

        return Scaffold(
          appBar: AppBar(
            title: AppBarTitle(text: context.t('attendance.mark_title')),
            actions: [
              IconButton(
                tooltip: context.t('attendance.edit_service'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editService(service),
              ),
              IconButton(
                tooltip: context.t('attendance.delete_service'),
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _deleteService(service),
              ),
            ],
          ),
          body: Column(
            children: [
              _Header(
                service: service,
                presentCount: present.length,
                dateFormat: _dateFormat,
              ),
              _Controls(
                householdMode: _householdMode,
                filter: _filter,
                controller: _searchController,
                onHouseholdChanged: (value) =>
                    setState(() => _householdMode = value),
                onFilterChanged: (value) => setState(() => _filter = value),
                onQueryChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
              Expanded(
                child: _buildRoster(roster, present),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : () => _save(present),
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.t('attendance.mark_save')),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoster(List<ChurchMembership> roster, Set<String> present) {
    if (roster.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            context.t('attendance.no_members'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final familyIdByMemberId = <String, String>{
      for (final member in roster) member.docId: member.familyId,
    };
    final visible = roster.where((member) {
      if (_filter == _RosterFilter.notMarked &&
          present.contains(member.docId)) {
        return false;
      }
      if (_query.isEmpty) return true;
      return member.displayName.toLowerCase().contains(_query) ||
          member.displayPhone.toLowerCase().contains(_query);
    }).toList(growable: false);

    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(context.t('attendance.no_members_match')),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final member = visible[index];
        final household = attendanceHouseholdIds(
          memberId: member.docId,
          familyId: member.familyId,
          familyIdByMemberId: familyIdByMemberId,
        );
        return _RosterTile(
          member: member,
          isPresent: present.contains(member.docId),
          householdSize: household.length,
          onTap: () => _toggle(member, household, present),
          onMarkFamily: household.length > 1
              ? () => _markHousehold(household, present)
              : null,
        );
      },
    );
  }

  void _toggle(
    ChurchMembership member,
    Set<String> household,
    Set<String> present,
  ) {
    setState(() {
      if (present.contains(member.docId)) {
        // Un-marking is always just the one person. Tapping someone off
        // should never quietly remove their whole family — the usual reason
        // is a mis-tap on one name.
        present.remove(member.docId);
        return;
      }
      present.addAll(_householdMode ? household : {member.docId});
    });
  }

  void _markHousehold(Set<String> household, Set<String> present) {
    final added = household.where((id) => !present.contains(id)).length;
    setState(() => present.addAll(household));
    if (added == 0) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'attendance.household_marked',
              parameters: {'count': added},
            ),
          ),
        ),
      );
  }

  Future<void> _save(Set<String> present) async {
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = context.t(
      'attendance.mark_saved',
      parameters: {'count': present.length},
    );
    final failed = context.t('attendance.save_failed');

    try {
      await ref.read(attendanceRepositoryProvider).savePresent(
            serviceId: widget.serviceId,
            present: present,
          );
      messenger.showSnackBar(SnackBar(content: Text(saved)));
      navigator.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Future<void> _editService(AttendanceService service) {
    return showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AttendanceServiceForm(existing: service),
    );
  }

  Future<void> _deleteService(AttendanceService service) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      icon: Icons.delete_outline_rounded,
      title: context.t('attendance.delete_confirm_title'),
      message: context.t('attendance.delete_confirm_message'),
      cancelLabel: context.t('settings.cancel'),
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = context.t('attendance.deleted');
    final failed = context.t('attendance.save_failed');
    try {
      await ref.read(attendanceRepositoryProvider).deleteService(service.id);
      messenger.showSnackBar(SnackBar(content: Text(deleted)));
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.service,
    required this.presentCount,
    required this.dateFormat,
  });

  final AttendanceService service;
  final int presentCount;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              dateFormat.format(service.date),
              attendanceServiceTypeLabel(context, service.type),
              // Without this, three Sunday worships on one date all head
              // this screen identically and an admin cannot tell which
              // register they are filling in.
              if (service.subheader.isNotEmpty) service.subheader,
            ].join(' · '),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            context.t('attendance.tally', parameters: {'count': presentCount}),
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.householdMode,
    required this.filter,
    required this.controller,
    required this.onHouseholdChanged,
    required this.onFilterChanged,
    required this.onQueryChanged,
  });

  final bool householdMode;
  final _RosterFilter filter;
  final TextEditingController controller;
  final ValueChanged<bool> onHouseholdChanged;
  final ValueChanged<_RosterFilter> onFilterChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: controller,
            hintText: context.t('attendance.search_member'),
            onChanged: onQueryChanged,
            suffixIcon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<_RosterFilter>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: _RosterFilter.everyone,
                      label: Text(context.t('attendance.show_everyone')),
                    ),
                    ButtonSegment(
                      value: _RosterFilter.notMarked,
                      label: Text(context.t('attendance.show_not_marked')),
                    ),
                  ],
                  selected: {filter},
                  onSelectionChanged: (value) => onFilterChanged(value.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: householdMode,
            onChanged: onHouseholdChanged,
            title: Text(
              context.t('attendance.household_mode'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              context.t('attendance.household_hint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterTile extends StatelessWidget {
  const _RosterTile({
    required this.member,
    required this.isPresent,
    required this.householdSize,
    required this.onTap,
    this.onMarkFamily,
  });

  final ChurchMembership member;
  final bool isPresent;
  final int householdSize;
  final VoidCallback onTap;
  final VoidCallback? onMarkFamily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isPresent ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                _PresenceCheck(isPresent: isPresent),
                const SizedBox(width: 12),
                AppProfileAvatar(
                  name: member.displayName,
                  imageUrl: member.displayPhotoUrl,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (householdSize > 1) ...[
                        const SizedBox(height: 2),
                        Text(
                          context.t(
                            'attendance.family_of',
                            parameters: {'count': householdSize},
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onMarkFamily != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onMarkFamily,
                    child: Text(
                      context.t(
                        'attendance.mark_family',
                        parameters: {'count': householdSize - 1},
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresenceCheck extends StatelessWidget {
  const _PresenceCheck({required this.isPresent});

  final bool isPresent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isPresent ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isPresent ? colors.primary : colors.outlineVariant,
          width: 2,
        ),
      ),
      child: isPresent
          ? Icon(Icons.check_rounded, size: 18, color: colors.onPrimary)
          : null,
    );
  }
}
