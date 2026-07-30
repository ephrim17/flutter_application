import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/side_drawer/prayer_providers.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class PrayForOthersSection implements MasterSection {
  const PrayForOthersSection({this.anchorKey});

  final GlobalKey? anchorKey;

  @override
  String get id => 'prayForOthers';

  @override
  int get order => 25;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: KeyedSubtree(
          key: anchorKey,
          child: const _PrayForOthersContent(),
        ),
      ),
    ];
  }
}

class _PrayForOthersContent extends ConsumerWidget {
  const _PrayForOthersContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayersAsync = ref.watch(prayersVisibleToChurchMembersProvider);

    return prayersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (prayers) {
        if (prayers.isEmpty) return const SizedBox.shrink();

        final cardWidth =
            math.min(MediaQuery.sizeOf(context).width * 0.82, 330.0);
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                text: context.t(
                  'for_you.pray_for_others.title',
                  fallback: 'Pray for others',
                ),
                padding: 16,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 3, 16, 14),
                child: Text(
                  context.t(
                    'for_you.pray_for_others.subtitle',
                    fallback: 'Stand with someone from your church in prayer.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              SizedBox(
                height: 238,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: prayers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => SizedBox(
                    width: cardWidth,
                    child: _PrayerForOthersCard(prayer: prayers[index]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrayerForOthersCard extends ConsumerWidget {
  const _PrayerForOthersCard({required this.prayer});

  final PrayerRequest prayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      prayer.expiryDate.year,
      prayer.expiryDate.month,
      prayer.expiryDate.day,
    );
    final daysLeft = expiry.difference(today).inDays.clamp(0, 999);

    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showPrayerForOthersDetails(context, prayer),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.volunteer_activism_rounded,
                      color: colors.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  _ExpiryPill(daysLeft: daysLeft),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                prayer.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: Text(
                  prayer.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              Divider(color: colors.outlineVariant.withValues(alpha: 0.65)),
              Row(
                children: [
                  Icon(
                    prayer.isAnonymous
                        ? Icons.visibility_off_outlined
                        : Icons.person_outline_rounded,
                    size: 17,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: _PrayerAuthorLabel(prayer: prayer)),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: colors.onSurfaceVariant,
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

class _PrayerAuthorLabel extends ConsumerWidget {
  const _PrayerAuthorLabel({required this.prayer});

  final PrayerRequest prayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        );
    if (prayer.isAnonymous) {
      return Text(
        context.t(
          'for_you.pray_for_others.anonymous',
          fallback: 'Anonymous request',
        ),
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return ref.watch(churchUserNameProvider(prayer.userId)).when(
          loading: () => Text(
            context.t(
              'for_you.pray_for_others.member',
              fallback: 'Church member',
            ),
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
          error: (_, __) => Text(
            context.t(
              'for_you.pray_for_others.member',
              fallback: 'Church member',
            ),
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
          data: (name) => Text(
            name?.trim().isNotEmpty == true
                ? name!
                : context.t(
                    'for_you.pray_for_others.member',
                    fallback: 'Church member',
                  ),
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        );
  }
}

class _ExpiryPill extends StatelessWidget {
  const _ExpiryPill({required this.daysLeft});

  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = daysLeft == 0
        ? context.t(
            'for_you.pray_for_others.ends_today',
            fallback: 'Ends today',
          )
        : '$daysLeft ${context.t('prayer.days_left', fallback: 'days left')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

Future<void> _showPrayerForOthersDetails(
  BuildContext context,
  PrayerRequest prayer,
) {
  final theme = Theme.of(context);
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.volunteer_activism_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    prayer.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
                  prayer.description,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Row(
              children: [
                Expanded(child: _PrayerAuthorLabel(prayer: prayer)),
                const SizedBox(width: 12),
                Icon(
                  Icons.event_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    DateFormat.yMMMd().format(prayer.expiryDate),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
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
