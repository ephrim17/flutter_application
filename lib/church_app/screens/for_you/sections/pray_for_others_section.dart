import 'dart:async';
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
            _PrayerRail(prayers: prayers),
          ],
        );
      },
    );
  }
}

/// The horizontal run of prayer cards.
///
/// A `Row` inside a scroll view rather than a fixed-height carousel: the
/// section's height comes from the tallest card, so a request renders here
/// exactly as it does in the Prayer Requests list. Laziness is no loss —
/// this is the active, church-visible, unexpired set, which is small.
///
/// Three things make a second card discoverable, which it was not when each
/// card took the full width and the next one sat entirely off-screen:
/// the card is narrowed so the next one peeks past the edge, the scroll
/// settles on a card instead of wherever it was released, and the dots say
/// how many there are and which one you are on.
class _PrayerRail extends StatefulWidget {
  const _PrayerRail({required this.prayers});

  final List<PrayerRequest> prayers;

  @override
  State<_PrayerRail> createState() => _PrayerRailState();
}

class _PrayerRailState extends State<_PrayerRail> {
  /// How much of the following card shows past the edge of the current one.
  /// Enough to read as a cut-off card rather than as a margin.
  static const double _peek = 30;

  final ScrollController _controller = ScrollController();
  int _index = 0;
  double _stride = 1;

  /// A wheel or trackpad on a desktop produces scroll updates without the
  /// clean end notification a finger lift gives, so settling only on
  /// `ScrollEndNotification` left the rail parked half-way between two
  /// cards. This fires shortly after movement stops, whatever caused it.
  Timer? _settleDebounce;

  bool get _hasMore => widget.prayers.length > 1;

  @override
  void dispose() {
    _settleDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSettle() {
    _settleDebounce?.cancel();
    _settleDebounce = Timer(
      const Duration(milliseconds: 140),
      _settleOnNearestCard,
    );
  }

  /// Which card the rail should come to rest on.
  ///
  /// Measured as movement away from the card it was resting on, not as the
  /// nearest card. A prayer card is nearly the full width, so "nearest"
  /// means travelling more than half of ~1,250px to advance one — fine for
  /// a finger drag, but a mouse wheel moves a few hundred pixels at a time
  /// and the rail would spring back every time, making the second card feel
  /// unreachable. A quarter of a card in one direction is a clear intent.
  int _restingIndex() {
    final anchor = _index * _stride;
    final delta = _controller.offset - anchor;

    if (delta > _stride * 0.25) return _index + 1;
    if (delta < -_stride * 0.25) return _index - 1;
    return _index;
  }

  void _settleOnNearestCard() {
    _settleDebounce?.cancel();
    if (!mounted || !_controller.hasClients || _stride <= 0) return;
    // Don't fight a fling that is still running.
    if (_controller.position.isScrollingNotifier.value) {
      _scheduleSettle();
      return;
    }

    final resting = _restingIndex().clamp(0, widget.prayers.length - 1);
    final target = (resting * _stride).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );

    if ((target - _controller.offset).abs() > 0.5) {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
    if (resting != _index) setState(() => _index = resting);
  }

  /// Keeps the dots honest while a drag is still in progress.
  void _trackIndex() {
    if (!_controller.hasClients || _stride <= 0) return;
    final current = _restingIndex().clamp(0, widget.prayers.length - 1);
    if (current != _index) setState(() => _index = current);
  }

  @override
  Widget build(BuildContext context) {
    // Measured from the space this section is given, not from the screen:
    // the two are the same today, but a card sized from the window inside a
    // narrower box is how this rail got clipped once already.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth -
            forYouSidePadding * 2 -
            (_hasMore ? _peek : 0);
        _stride = cardWidth + forYouCardGap;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  _trackIndex();
                  _scheduleSettle();
                } else if (notification is ScrollEndNotification) {
                  _settleOnNearestCard();
                }
                return false;
              },
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: forYouSidePadding,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0;
                        index < widget.prayers.length;
                        index++) ...[
                      if (index > 0) const SizedBox(width: forYouCardGap),
                      SizedBox(
                        width: cardWidth,
                        child: PrayerRequestCard(
                          prayer: widget.prayers[index],
                          onTap: () => _showPrayerForOthersDetails(
                            context,
                            widget.prayers[index],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_hasMore) ...[
              const SizedBox(height: 10),
              Center(
                  child: _PrayerRailDots(
                count: widget.prayers.length,
                current: _index,
              )),
            ],
          ],
        );
      },
    );
  }
}

/// Which card of how many. The same dot treatment the Home carousels use,
/// so "there is more than one of these" looks the same everywhere.
class _PrayerRailDots extends StatelessWidget {
  const _PrayerRailDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == current ? 10 : 8,
            height: index == current ? 10 : 8,
            decoration: BoxDecoration(
              color: index == current
                  ? colors.onSecondaryFixedVariant
                  : colors.secondaryFixedDim,
              shape: BoxShape.circle,
            ),
          ),
      ],
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
