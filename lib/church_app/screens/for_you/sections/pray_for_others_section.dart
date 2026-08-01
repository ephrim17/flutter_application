import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/side_drawer/prayer_providers.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_card_layout.dart';
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
                text: context.t('for_you.pray_for_others.title'),
                padding: 16,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 3, 16, 14),
                child: Text(
                  context.t('for_you.pray_for_others.subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              SizedBox(
                height: forYouPrimaryCardHeight,
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.09),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surfaceContainerLowest,
                colors.primaryContainer.withValues(alpha: 0.48),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.16),
            ),
          ),
          child: InkWell(
            onTap: () => _showPrayerForOthersDetails(context, prayer),
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -36,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(alpha: 0.07),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.volunteer_activism_rounded,
                                  color: colors.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  context.t(
                                    'for_you.pray_for_others.request_label',
                                  ),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          _ExpiryPill(daysLeft: daysLeft),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        prayer.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
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
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 9, 7, 9),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                prayer.isAnonymous
                                    ? Icons.visibility_off_outlined
                                    : Icons.person_outline_rounded,
                                size: 17,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: _PrayerAuthorLabel(prayer: prayer),
                            ),
                            Text(
                              context.t('for_you.pray_for_others.open_action'),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 17,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
        context.t('for_you.pray_for_others.anonymous'),
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return ref.watch(churchUserNameProvider(prayer.userId)).when(
          loading: () => Text(
            context.t('for_you.pray_for_others.member'),
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
          error: (_, __) => Text(
            context.t('for_you.pray_for_others.member'),
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
          data: (name) => Text(
            name?.trim().isNotEmpty == true
                ? name!
                : context.t('for_you.pray_for_others.member'),
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
        ? context.t('for_you.pray_for_others.ends_today')
        : context.t(
            daysLeft == 1
                ? 'for_you.pray_for_others.one_day_left'
                : 'for_you.pray_for_others.days_left',
            parameters: {'count': daysLeft},
          );
    final isUrgent = daysLeft <= 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isUrgent
            ? colors.errorContainer.withValues(alpha: 0.82)
            : colors.primaryContainer.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isUrgent
                  ? colors.onErrorContainer
                  : colors.onPrimaryContainer,
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
