import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/carousel_arrow.dart';

class AutoScrollCarousel extends StatefulWidget {
  const AutoScrollCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.height,
    this.viewportFraction = 0.9,
    this.autoScroll = false, // ✅ caller decides
    this.autoScrollDuration = const Duration(seconds: 4),
    this.animationDuration = const Duration(milliseconds: 500),
    this.spacing = 12,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  final double? height;
  final double viewportFraction;

  /// ✅ Enable / Disable auto scroll
  final bool autoScroll;

  final Duration autoScrollDuration;
  final Duration animationDuration;
  final double spacing;

  @override
  State<AutoScrollCarousel> createState() => _AutoScrollCarouselState();
}

class _AutoScrollCarouselState extends State<AutoScrollCarousel> {
  late final PageController _controller;
  int _currentIndex = 0;
  bool _isAutoScrolling = false;

  /// Set the moment the reader moves the carousel themselves, by an arrow,
  /// a dot or a drag. Auto-advance then stops for good: a carousel that
  /// takes itself back after someone has chosen a card is the same
  /// complaint as one that moves while they are reading.
  bool _userTookOver = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: widget.viewportFraction);

    if (widget.autoScroll && widget.itemCount > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startAutoScroll();
      });
    }
  }

  void _startAutoScroll() async {
    if (_isAutoScrolling) return;
    _isAutoScrolling = true;

    while (mounted &&
        widget.autoScroll &&
        !_userTookOver &&
        widget.itemCount > 1) {
      await Future.delayed(widget.autoScrollDuration);

      if (!mounted || _userTookOver) break;

      _currentIndex = (_currentIndex + 1) % widget.itemCount;

      await _controller.animateToPage(
        _currentIndex,
        duration: widget.animationDuration,
        curve: Curves.easeOut,
      );

      if (mounted) {
        setState(() {});
      }
    }

    _isAutoScrolling = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.itemCount) return;
    _userTookOver = true;
    _currentIndex = index;
    _controller.animateToPage(
      index,
      duration: widget.animationDuration,
      curve: Curves.easeOutCubic,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasDots = widget.itemCount > 1;
    // 8 gap + a 10pt dot inside 8pt of vertical padding either side, which
    // is what makes the dot tappable. Under-reserving this overflows the
    // fixed card height the carousel is given.
    const dotsHeight = 34.0;

    final pageHeight = hasDots ? (widget.height! - dotsHeight) : widget.height!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: pageHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A `PageView` only advances once a drag passes half a page.
              // On a phone that is a flick; on a desktop, where the card can
              // be 1,300px wide, it means dragging 650px with a mouse — and
              // a wheel does not page it at all, it drifts and springs back.
              // So the dots could say "there are two of these" while the
              // second one stayed effectively unreachable. These arrows are
              // the pointer's way in.
              final showArrows =
                  hasDots && constraints.maxWidth >= carouselArrowBreakpoint;

              return Stack(
                children: [
                  Positioned.fill(
                    child: NotificationListener<ScrollStartNotification>(
                      onNotification: (notification) {
                        // dragDetails is null for the controller's own
                        // animations, so this is a real swipe.
                        if (notification.dragDetails != null) {
                          _userTookOver = true;
                        }
                        return false;
                      },
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: widget.itemCount,
                        onPageChanged: (index) {
                          setState(() => _currentIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: widget.spacing / 2),
                            child: widget.itemBuilder(context, index),
                          );
                        },
                      ),
                    ),
                  ),
                  if (showArrows) ...[
                    CarouselArrow(
                      alignment: Alignment.centerLeft,
                      icon: Icons.chevron_left_rounded,
                      onTap: _currentIndex > 0
                          ? () => _goTo(_currentIndex - 1)
                          : null,
                    ),
                    CarouselArrow(
                      alignment: Alignment.centerRight,
                      icon: Icons.chevron_right_rounded,
                      onTap: _currentIndex < widget.itemCount - 1
                          ? () => _goTo(_currentIndex + 1)
                          : null,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        if (hasDots) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.itemCount, (index) {
              final isActive = index == _currentIndex;

              // Tappable, not just an indicator. On a phone the dots are
              // the only other way to reach a card without a long swipe,
              // and the hit area is padded out to something a thumb can
              // actually land on.
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _goTo(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: isActive ? 10 : 8,
                    height: isActive ? 10 : 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Theme.of(context)
                              .colorScheme
                              .onSecondaryFixedVariant
                          : Theme.of(context).colorScheme.secondaryFixedDim,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
