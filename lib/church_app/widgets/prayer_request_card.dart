import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One prayer request, as a card.
///
/// Shared verbatim by the Prayer Requests screen and the For You "Pray for
/// others" section. For You used to draw its own narrower, fixed-height
/// variant, so the same request rendered at two different sizes depending on
/// where you met it. One widget means one set of metrics: whatever padding,
/// radius, type scale and line clamps live here apply in both places, and
/// they cannot drift apart again.

class PrayerRequestCard extends ConsumerWidget {
  const PrayerRequestCard({
    super.key,
    required this.prayer,
    required this.onTap,
    this.trailing,
    this.fillHeight = false,
  });

  final PrayerRequest prayer;
  final VoidCallback onTap;

  /// Shown at the top-right of the card. The Prayer Requests screen puts its
  /// overflow menu here; For You passes nothing, because a reader of someone
  /// else's request has nothing to act on.
  final Widget? trailing;

  /// Push the footer to the bottom of whatever height the card is given.
  ///
  /// The Prayer Requests list leaves this off, so the card is as tall as its
  /// own content. A rail sets it, because there every card is given the
  /// height of the tallest one and a footer left where the text ended would
  /// sit at a different height on each card.
  final bool fillHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final daysLeft = prayerDaysLeft(prayer.expiryDate);

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
                  PrayerRequestIcon(
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
                  if (trailing != null) trailing!,
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
              if (fillHeight) const Spacer() else const SizedBox(height: 16),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.65),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    if (!prayer.isAnonymous) ...[
                      Icon(
                        Icons.person_outline_rounded,
                        size: 17,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: ref
                            .watch(churchMemberNameProvider(prayer.userId))
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

/// The rounded tile that stands in for the person, used on the card, in the
/// detail sheet and in the create/edit modal.
class PrayerRequestIcon extends StatelessWidget {
  const PrayerRequestIcon({
    super.key,
    required this.isAnonymous,
    this.size = 42,
  });

  final bool isAnonymous;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(
        isAnonymous
            ? Icons.favorite_outline_rounded
            : Icons.volunteer_activism_outlined,
        color: colors.onPrimaryContainer,
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
