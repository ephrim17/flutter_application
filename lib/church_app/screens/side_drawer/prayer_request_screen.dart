import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/app_popup_menu.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/side_drawer/prayer_providers.dart';
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';

class PrayerRequestScreen extends ConsumerStatefulWidget {
  const PrayerRequestScreen({super.key});

  @override
  ConsumerState<PrayerRequestScreen> createState() =>
      _PrayerRequestScreenState();
}

class _PrayerRequestScreenState extends ConsumerState<PrayerRequestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await logChurchAnalyticsEvent(
        ref,
        name: 'prayer_screen_opened',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final selectedSegment = ref.watch(prayerSegmentProvider);
    final segment = !isAdmin && selectedSegment == PrayerSegment.all
        ? PrayerSegment.my
        : selectedSegment;
    final currentChurchId =
        ref.watch(currentChurchIdProvider).asData?.value ?? '';

    final myPrayersAsync = ref.watch(myPrayerRequestsProvider);
    final allPrayersAsync =
        isAdmin ? ref.watch(allPrayerRequestsProvider) : null;
    final globalPrayersAsync = ref.watch(globalPrayerRequestsProvider);
    final prayersAsync = switch (segment) {
      PrayerSegment.my => myPrayersAsync,
      PrayerSegment.all => allPrayersAsync ?? myPrayersAsync,
      PrayerSegment.global => globalPrayersAsync,
    };
    final availableSegments = <PrayerSegment>[
      PrayerSegment.my,
      if (isAdmin) PrayerSegment.all,
      PrayerSegment.global,
    ];
    final counts = <PrayerSegment, int>{
      PrayerSegment.my: myPrayersAsync.asData?.value.length ?? 0,
      if (isAdmin)
        PrayerSegment.all: allPrayersAsync?.asData?.value.length ?? 0,
      PrayerSegment.global: globalPrayersAsync.asData?.value.length ?? 0,
    };
    final selectedPrayers = prayersAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t('prayer.screen_title'),
        ),
      ),
      body: Column(
        children: [
          _PrayerHeader(
            segment: segment,
            availableSegments: availableSegments,
            counts: counts,
            onSegmentSelected: (selected) {
              ref.read(prayerSegmentProvider.notifier).state = selected;
            },
            onCreate: selectedPrayers?.isNotEmpty == true &&
                    segment != PrayerSegment.global
                ? () => _openCreatePrayer(segment)
                : null,
          ),
          Expanded(
            child: prayersAsync.when(
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (error, _) => _PrayerErrorView(
                onRetry: () => _retry(segment),
              ),
              data: (prayers) {
                if (prayers.isEmpty) {
                  return _PrayerEmptyState(
                    segment: segment,
                    onCreate: segment == PrayerSegment.global
                        ? null
                        : () => _openCreatePrayer(segment),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: prayers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final prayer = prayers[index];
                    return _PrayerRequestCard(
                      prayer: prayer,
                      segment: segment,
                      onTap: () => _openPrayer(prayer, segment),
                      actions: _PrayerActions(
                        prayer: prayer,
                        segment: segment,
                        canManageGlobal: isAdmin &&
                            (segment != PrayerSegment.global ||
                                prayer.sourceChurchId == currentChurchId),
                        onEdit: () => _editPrayer(prayer, segment),
                        onDelete: () => _deletePrayer(prayer, segment),
                        onSetGlobal: (isGlobal) =>
                            _setPrayerGlobal(prayer, segment, isGlobal),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreatePrayer(PrayerSegment segment) async {
    await logChurchAnalyticsEvent(
      ref,
      name: 'prayer_request_create_started',
      parameters: {'segment': segment.name},
    );
    if (!mounted) return;
    await showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddPrayerModal(),
    );
  }

  Future<void> _openPrayer(
    PrayerRequest prayer,
    PrayerSegment segment,
  ) async {
    await logChurchAnalyticsEvent(
      ref,
      name: 'prayer_request_opened',
      parameters: {
        'prayer_id': prayer.id,
        'segment': segment.name,
        'is_anonymous': prayer.isAnonymous,
      },
    );
    if (!mounted) return;
    await _showPrayerDetailsSheet(context, prayer);
  }

  void _retry(PrayerSegment segment) {
    switch (segment) {
      case PrayerSegment.my:
        ref.invalidate(myPrayerRequestsProvider);
      case PrayerSegment.all:
        ref.invalidate(allPrayerRequestsProvider);
      case PrayerSegment.global:
        ref.invalidate(globalPrayerRequestsProvider);
    }
  }

  Future<void> _editPrayer(
    PrayerRequest prayer,
    PrayerSegment segment,
  ) async {
    await logChurchAnalyticsEvent(
      ref,
      name: 'prayer_request_edit_started',
      parameters: {
        'prayer_id': prayer.id,
        'segment': segment.name,
      },
    );
    if (!mounted) return;
    await showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddPrayerModal(existing: prayer),
    );
  }

  Future<void> _deletePrayer(
    PrayerRequest prayer,
    PrayerSegment segment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text(
          context.t('prayer.delete_confirm_title'),
        ),
        content: Text(
          context.t('prayer.delete_confirm_message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('settings.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(prayerRepositoryProvider).deletePrayer(prayer.id);
      await logChurchAnalyticsEvent(
        ref,
        name: 'prayer_request_deleted',
        parameters: {
          'prayer_id': prayer.id,
          'segment': segment.name,
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _setPrayerGlobal(
    PrayerRequest prayer,
    PrayerSegment segment,
    bool isGlobal,
  ) async {
    final prayerId =
        segment == PrayerSegment.global ? prayer.sourcePrayerId : prayer.id;
    if (prayerId.isEmpty) return;

    try {
      await ref.read(prayerRepositoryProvider).setPrayerGlobal(
            prayerId: prayerId,
            isGlobal: isGlobal,
          );
      await logChurchAnalyticsEvent(
        ref,
        name: isGlobal
            ? 'prayer_request_made_global'
            : 'prayer_request_removed_from_global',
        parameters: {'prayer_id': prayerId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isGlobal
                ? context.t('prayer.global_success')
                : context.t('prayer.global_removed'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

enum _PrayerAction { edit, makeGlobal, removeGlobal, delete }

class _PrayerActions extends StatelessWidget {
  const _PrayerActions({
    required this.prayer,
    required this.segment,
    required this.canManageGlobal,
    required this.onEdit,
    required this.onDelete,
    required this.onSetGlobal,
  });

  final PrayerRequest prayer;
  final PrayerSegment segment;
  final bool canManageGlobal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onSetGlobal;

  @override
  Widget build(BuildContext context) {
    final actions = <AppPopupMenuAction<_PrayerAction>>[
      if (segment == PrayerSegment.my)
        AppPopupMenuAction(
          value: _PrayerAction.edit,
          icon: Icons.edit_outlined,
          label: context.t('prayer.edit_action'),
        ),
      if (canManageGlobal && !prayer.isGlobal)
        AppPopupMenuAction(
          value: _PrayerAction.makeGlobal,
          icon: Icons.public_rounded,
          label: context.t('prayer.make_global_action'),
        ),
      if (canManageGlobal && prayer.isGlobal)
        AppPopupMenuAction(
          value: _PrayerAction.removeGlobal,
          icon: Icons.public_off_outlined,
          label: context.t('prayer.remove_global_action'),
        ),
      if (segment != PrayerSegment.global)
        AppPopupMenuAction(
          value: _PrayerAction.delete,
          icon: Icons.delete_outline_rounded,
          label: context.t('common.delete'),
          color: Theme.of(context).colorScheme.error,
        ),
    ];

    return AppPopupMenu<_PrayerAction>(
      actions: actions,
      onSelected: (action) {
        switch (action) {
          case _PrayerAction.edit:
            onEdit();
          case _PrayerAction.makeGlobal:
            onSetGlobal(true);
          case _PrayerAction.removeGlobal:
            onSetGlobal(false);
          case _PrayerAction.delete:
            onDelete();
        }
      },
    );
  }
}

Future<void> _showPrayerDetailsSheet(
  BuildContext context,
  PrayerRequest prayer,
) {
  final theme = Theme.of(context);
  final sourceName = prayer.sourceChurchName.trim();
  return showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                _PrayerIcon(
                  isGlobal: prayer.isGlobal,
                  isAnonymous: prayer.isAnonymous,
                  size: 48,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prayer.title.trim().isEmpty
                            ? 'Prayer Request'
                            : prayer.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (prayer.isGlobal && sourceName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          sourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  prayer.description.trim().isEmpty
                      ? 'No description provided.'
                      : prayer.description,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 19,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t(
                      'prayer.active_until',
                      parameters: {
                        'date': DateFormat.yMMMd().format(prayer.expiryDate),
                      },
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PrayerHeader extends StatelessWidget {
  const _PrayerHeader({
    required this.segment,
    required this.availableSegments,
    required this.counts,
    required this.onSegmentSelected,
    this.onCreate,
  });

  final PrayerSegment segment;
  final List<PrayerSegment> availableSegments;
  final Map<PrayerSegment, int> counts;
  final ValueChanged<PrayerSegment> onSegmentSelected;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primaryContainer.withValues(alpha: 0.72),
              colors.tertiaryContainer.withValues(alpha: 0.48),
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.volunteer_activism_rounded,
                    color: colors.primary,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('prayer.community_title'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t('prayer.community_subtitle'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onCreate != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: onCreate,
                    tooltip: context.t('prayer.new_request'),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0;
                      index < availableSegments.length;
                      index++) ...[
                    _PrayerScopeChip(
                      segment: availableSegments[index],
                      count: counts[availableSegments[index]] ?? 0,
                      selected: segment == availableSegments[index],
                      onTap: () => onSegmentSelected(availableSegments[index]),
                    ),
                    if (index != availableSegments.length - 1)
                      const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerScopeChip extends StatelessWidget {
  const _PrayerScopeChip({
    required this.segment,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final PrayerSegment segment;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;

    return Material(
      color: selected
          ? colors.primaryContainer
          : colors.surface.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 142,
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.52)
                  : colors.outlineVariant.withValues(alpha: 0.48),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(_scopeIcon(segment), size: 19, color: foreground),
                  const Spacer(),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _scopeChipLabel(context, segment),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context
                    .t(
                      'prayer.requests_count',
                      fallback: '{count} requests',
                    )
                    .replaceAll('{count}', '$count'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? foreground.withValues(alpha: 0.76)
                      : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrayerRequestCard extends ConsumerWidget {
  const _PrayerRequestCard({
    required this.prayer,
    required this.segment,
    required this.onTap,
    required this.actions,
  });

  final PrayerRequest prayer;
  final PrayerSegment segment;
  final VoidCallback onTap;
  final Widget actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final daysLeft =
        prayer.expiryDate.difference(DateTime.now()).inDays.clamp(0, 999);

    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.72),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PrayerIcon(
                    isGlobal: prayer.isGlobal,
                    isAnonymous: prayer.isAnonymous,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prayer.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (prayer.isGlobal)
                              _PrayerBadge(
                                icon: Icons.public_rounded,
                                label: prayer.sourceChurchName.trim().isEmpty
                                    ? context.t('prayer.global_badge')
                                    : prayer.sourceChurchName,
                              ),
                            if (prayer.isAnonymous)
                              _PrayerBadge(
                                icon: Icons.visibility_off_outlined,
                                label: context.t('prayer.anonymous_badge'),
                              ),
                            if (prayer.visibleToChurchMembers)
                              _PrayerBadge(
                                icon: Icons.people_alt_outlined,
                                label:
                                    context.t('prayer.visible_to_church_badge'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions,
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  prayer.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.65),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    if (!prayer.isAnonymous &&
                        segment != PrayerSegment.global) ...[
                      Icon(
                        Icons.person_outline_rounded,
                        size: 17,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: ref
                            .watch(churchUserNameProvider(prayer.userId))
                            .when(
                              loading: () => Text(
                                context.t('prayer.by_loading'),
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium,
                              ),
                              error: (_, __) => Text(
                                context.t('prayer.by_unknown'),
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium,
                              ),
                              data: (name) => Text(
                                name?.trim().isNotEmpty == true
                                    ? name!
                                    : context.t('prayer.by_unknown'),
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                      ),
                    ] else
                      const Spacer(),
                    Icon(
                      Icons.schedule_rounded,
                      size: 17,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      daysLeft == 0
                          ? context.t('prayer.ends_today')
                          : '$daysLeft ${context.t('prayer.days_left')}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrayerIcon extends StatelessWidget {
  const _PrayerIcon({
    required this.isGlobal,
    required this.isAnonymous,
    this.size = 42,
  });

  final bool isGlobal;
  final bool isAnonymous;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isGlobal ? colors.tertiaryContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(
        isGlobal
            ? Icons.public_rounded
            : isAnonymous
                ? Icons.favorite_outline_rounded
                : Icons.volunteer_activism_outlined,
        color:
            isGlobal ? colors.onTertiaryContainer : colors.onPrimaryContainer,
        size: size * 0.5,
      ),
    );
  }
}

class _PrayerBadge extends StatelessWidget {
  const _PrayerBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerEmptyState extends StatelessWidget {
  const _PrayerEmptyState({
    required this.segment,
    this.onCreate,
  });

  final PrayerSegment segment;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.volunteer_activism_outlined,
                size: 34,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.t('prayer.none'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              segment == PrayerSegment.global
                  ? context.t('prayer.global_empty_hint')
                  : context.t('prayer.empty_hint'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (onCreate != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  context.t('prayer.new_request'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrayerErrorView extends StatelessWidget {
  const _PrayerErrorView({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              context.t('prayer.load_error'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                context.t('feed.retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _scopeIcon(PrayerSegment segment) => switch (segment) {
      PrayerSegment.my => Icons.person_outline_rounded,
      PrayerSegment.all => Icons.groups_2_outlined,
      PrayerSegment.global => Icons.public_rounded,
    };

String _scopeChipLabel(BuildContext context, PrayerSegment segment) =>
    switch (segment) {
      PrayerSegment.my => context.t('prayer.my_requests_tab'),
      PrayerSegment.all => context.t('prayer.all_requests_tab'),
      PrayerSegment.global => context.t('prayer.global_requests_tab'),
    };

enum PrayerSegment {
  my,
  all,
  global,
}

final prayerSegmentProvider =
    StateProvider<PrayerSegment>((ref) => PrayerSegment.my);

class AddPrayerModal extends ConsumerStatefulWidget {
  final PrayerRequest? existing;
  const AddPrayerModal({super.key, this.existing});

  @override
  ConsumerState<AddPrayerModal> createState() => _AddPrayerModalState();
}

class _AddPrayerModalState extends ConsumerState<AddPrayerModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _isAnonymous = false;
  bool _visibleToChurchMembers = false;
  bool _showExpiryError = false;
  DateTime? _expiryDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.existing != null) {
      _titleCtrl.text = widget.existing!.title;
      _descCtrl.text = widget.existing!.description;
      _isAnonymous = widget.existing!.isAnonymous;
      _visibleToChurchMembers = widget.existing!.visibleToChurchMembers;
      _expiryDate = widget.existing!.expiryDate;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                _PrayerIcon(
                  isGlobal: false,
                  isAnonymous: _isAnonymous,
                  size: 46,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existing == null
                            ? context.t('prayer.create_title')
                            : context.t('prayer.edit_title'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.t('prayer.form_hint'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('prayer.healing_verse_title'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: primaryColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.t('prayer.healing_verse'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.t('prayer.healing_verse_reference'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: context.t('prayer.title_label'),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.t('prayer.title_required')
                  : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.t('prayer.description_label'),
                alignLabelWithHint: true,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.t('prayer.description_required')
                  : null,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                secondary: const Icon(Icons.visibility_off_outlined),
                title: Text(
                  context.t('prayer.submit_anonymous'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  context.t('prayer.anonymous_hint'),
                ),
                value: _isAnonymous,
                onChanged: (v) {
                  setState(() => _isAnonymous = v);
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                secondary: const Icon(Icons.people_alt_outlined),
                title: Text(
                  context.t('prayer.visible_to_church_title'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  context.t('prayer.visible_to_church_hint'),
                ),
                value: _visibleToChurchMembers,
                onChanged: (value) {
                  setState(() => _visibleToChurchMembers = value);
                },
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: _showExpiryError
                    ? BorderSide(
                        color: theme.colorScheme.error,
                        width: 1.5,
                      )
                    : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  context.t('prayer.expiry_date_title'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _expiryDate == null
                          ? context.t('prayer.select_expiry_date')
                          : DateFormat.yMMMMd().format(_expiryDate!),
                    ),
                    if (_showExpiryError) ...[
                      const SizedBox(height: 5),
                      Text(
                        context.t('prayer.select_expiry_required'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate ?? today,
                    firstDate: today,
                    lastDate: today.add(const Duration(days: 30)),
                  );

                  if (picked != null) {
                    setState(() {
                      _expiryDate = picked;
                      _showExpiryError = false;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite_rounded),
                label: Text(
                  widget.existing == null
                      ? context.t('prayer.submit_action')
                      : context.t('prayer.update_action'),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_expiryDate == null) {
      setState(() => _showExpiryError = true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final currentChurchId = await ref.read(currentChurchIdProvider.future);

      if (widget.existing == null) {
        await ref.read(prayerRepositoryProvider).addPrayer(
              title: _titleCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              isAnonymous: _isAnonymous,
              visibleToChurchMembers: _visibleToChurchMembers,
              expiryDate: _expiryDate!,
            );
        await FirebaseAnalytics.instance.logEvent(
          name: 'prayer_request_created',
          parameters: {
            if (currentChurchId != null && currentChurchId.trim().isNotEmpty)
              'church_id': currentChurchId,
            'is_anonymous': _isAnonymous.toString(),
            'visible_to_church_members': _visibleToChurchMembers.toString(),
          },
        );
      } else {
        await ref.read(prayerRepositoryProvider).updatePrayer(
              prayerId: widget.existing!.id,
              title: _titleCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              isAnonymous: _isAnonymous,
              visibleToChurchMembers: _visibleToChurchMembers,
              expiryDate: _expiryDate!,
            );
        await FirebaseAnalytics.instance.logEvent(
          name: 'prayer_request_updated',
          parameters: {
            if (currentChurchId != null && currentChurchId.trim().isNotEmpty)
              'church_id': currentChurchId,
            'prayer_id': widget.existing!.id,
            'is_anonymous': _isAnonymous.toString(),
            'visible_to_church_members': _visibleToChurchMembers.toString(),
          },
        );
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('prayer.saved_success'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', '').trim().isEmpty
                ? context.t('common.unknown_error')
                : e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
