import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/carousel_arrow.dart';

/// A horizontal run of cards that are all the same size, settles on a card
/// rather than wherever it was released, and says how many there are.
///
/// Unlike [AutoScrollCarousel] this is not a `PageView`: the rail has no
/// fixed height, it takes the height of its tallest card and gives every
/// card that height. A card whose content varies — a prayer request with a
/// one-line description next to one with three — therefore renders at one
/// size across the rail instead of each card ending wherever its own text
/// happens to stop, which left the shorter card floating above a ragged
/// bottom edge next to its neighbour.
///
/// Three things make a second card discoverable: [peek] leaves the next
/// card cut off past the edge, the scroll settles on a card, and the dots
/// say how many there are and which one you are on. The dots are tappable,
/// which is the way across without a long swipe.
class SnappingCardRail extends StatefulWidget {
  const SnappingCardRail({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.sidePadding = 16,
    this.gap = 12,
    this.peek = 30,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// The gutter the rail's first and last card sit on.
  final double sidePadding;

  /// Between two cards.
  final double gap;

  /// How much of the following card shows past the edge of the current one.
  /// Enough to read as a cut-off card rather than as a margin. Applied only
  /// when there is a following card.
  final double peek;

  @override
  State<SnappingCardRail> createState() => _SnappingCardRailState();
}

class _SnappingCardRailState extends State<SnappingCardRail> {
  final ScrollController _controller = ScrollController();
  int _index = 0;
  double _stride = 1;

  /// A wheel or trackpad on a desktop produces scroll updates without the
  /// clean end notification a finger lift gives, so settling only on
  /// `ScrollEndNotification` left the rail parked half-way between two
  /// cards. This fires shortly after movement stops, whatever caused it.
  Timer? _settleDebounce;

  bool get _hasMore => widget.itemCount > 1;

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
  /// nearest card. A card here is nearly the full width, so "nearest" means
  /// travelling more than half of ~1,250px to advance one — fine for a
  /// finger drag, but a mouse wheel moves a few hundred pixels at a time
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

    final resting = _restingIndex().clamp(0, widget.itemCount - 1);
    _animateTo(resting);
    if (resting != _index) setState(() => _index = resting);
  }

  void _animateTo(int index) {
    if (!_controller.hasClients) return;
    final target = (index * _stride).clamp(
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
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.itemCount) return;
    _settleDebounce?.cancel();
    _animateTo(index);
    if (index != _index) setState(() => _index = index);
  }

  /// Keeps the dots honest while a drag is still in progress.
  void _trackIndex() {
    if (!_controller.hasClients || _stride <= 0) return;
    final current = _restingIndex().clamp(0, widget.itemCount - 1);
    if (current != _index) setState(() => _index = current);
  }

  @override
  Widget build(BuildContext context) {
    // Measured from the space this rail is given, not from the screen: the
    // two are the same today, but a card sized from the window inside a
    // narrower box is how this rail got clipped once already.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth -
            widget.sidePadding * 2 -
            (_hasMore ? widget.peek : 0);
        _stride = cardWidth + widget.gap;

        // A card here is nearly the full width, so reaching the next one
        // with a mouse means a long drag, and a wheel only nudges it. The
        // arrows are the pointer's way across, exactly as on the Home
        // carousels — same breakpoint, same treatment at the ends.
        final showArrows =
            _hasMore && constraints.maxWidth >= carouselArrowBreakpoint;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
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
                    padding:
                        EdgeInsets.symmetric(horizontal: widget.sidePadding),
                    // The tallest card sets the height and every card is given
                    // it, so the rail has one bottom edge rather than one per
                    // card.
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var index = 0;
                              index < widget.itemCount;
                              index++) ...[
                            if (index > 0) SizedBox(width: widget.gap),
                            SizedBox(
                              width: cardWidth,
                              child: widget.itemBuilder(context, index),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (showArrows)
                  Positioned.fill(
                    child: Row(
                      children: [
                        CarouselArrow(
                          alignment: Alignment.centerLeft,
                          icon: Icons.chevron_left_rounded,
                          onTap: _index > 0 ? () => _goTo(_index - 1) : null,
                        ),
                        const Spacer(),
                        CarouselArrow(
                          alignment: Alignment.centerRight,
                          icon: Icons.chevron_right_rounded,
                          onTap: _index < widget.itemCount - 1
                              ? () => _goTo(_index + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (_hasMore) ...[
              const SizedBox(height: 10),
              Center(
                child: SnappingRailDots(
                  count: widget.itemCount,
                  current: _index,
                  onTap: _goTo,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Which card of how many. The same dot treatment the Home carousels use,
/// so "there is more than one of these" looks and behaves the same
/// everywhere — tappable included.
class SnappingRailDots extends StatelessWidget {
  const SnappingRailDots({
    super.key,
    required this.count,
    required this.current,
    this.onTap,
  });

  final int count;
  final int current;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < count; index++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null ? null : () => onTap!(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: index == current ? 10 : 8,
                height: index == current ? 10 : 8,
                decoration: BoxDecoration(
                  color: index == current
                      ? colors.onSecondaryFixedVariant
                      : colors.secondaryFixedDim,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
