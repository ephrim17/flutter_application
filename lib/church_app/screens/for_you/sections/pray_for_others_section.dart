import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/side_drawer/prayer_providers.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_card_layout.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/prayer_request_card.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class PrayForOthersSection implements MasterSection {
  const PrayForOthersSection({this.anchorKey});

  final GlobalKey? anchorKey;

  @override
  String get id => 'prayForOthers';

  @override
  int get order => 15;

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

        // Exactly the width a card gets in the Prayer Requests list, whose
        // ListView uses the same 16pt side padding. Together with
        // PrayerRequestCard's own intrinsic height, that makes a request
        // render identically in both places instead of shrinking into a
        // narrow fixed-height carousel tile here.
        final cardWidth =
            MediaQuery.sizeOf(context).width - forYouSidePadding * 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              text: context.t('for_you.pray_for_others.title'),
              padding: forYouSidePadding,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                forYouSidePadding,
                forYouSubtitleGap,
                forYouSidePadding,
                forYouHeaderGap,
              ),
              child: Text(
                context.t('for_you.pray_for_others.subtitle'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            // A Row rather than a horizontal ListView: the section's height
            // now comes from the tallest card instead of a fixed constant,
            // which is the whole point. Laziness is no loss — this is the
            // active, church-visible, unexpired set, which is small.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: forYouSidePadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < prayers.length; index++) ...[
                    if (index > 0) const SizedBox(width: forYouCardGap),
                    SizedBox(
                      width: cardWidth,
                      child: PrayerRequestCard(
                        prayer: prayers[index],
                        onTap: () => _showPrayerForOthersDetails(
                          context,
                          prayers[index],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
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

    return ref.watch(churchMemberNameProvider(prayer.userId)).when(
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

Future<void> _showPrayerForOthersDetails(
  BuildContext context,
  PrayerRequest prayer,
) {
  final theme = Theme.of(context);
  return showAppModalBottomSheet<void>(
    context: context,
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
