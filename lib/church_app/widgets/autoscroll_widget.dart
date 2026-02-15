import 'package:flutter/material.dart';

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

    while (mounted && widget.autoScroll && widget.itemCount > 1) {
      await Future.delayed(widget.autoScrollDuration);

      if (!mounted) break;

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

  @override
Widget build(BuildContext context) {
  final hasDots = widget.itemCount > 1;
  const dotsHeight = 18.0; // approx 8 spacing + 10 dot size

  final pageHeight =
      hasDots ? (widget.height! - dotsHeight) : widget.height!;

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        height: pageHeight,
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.itemCount,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
          },
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(right: widget.spacing),
              child: widget.itemBuilder(context, index),
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

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 10 : 8,
              height: isActive ? 10 : 8,
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.onSecondaryFixedVariant
                    : Theme.of(context)
                        .colorScheme
                        .secondaryFixedDim,
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ],
    ],
  );
}
}
