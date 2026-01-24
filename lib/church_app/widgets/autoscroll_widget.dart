import 'package:flutter/material.dart';

class AutoScrollCarousel extends StatefulWidget {
  const AutoScrollCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.height,
    this.viewportFraction = 0.9,
    this.autoScrollDuration = const Duration(seconds: 4),
    this.animationDuration = const Duration(milliseconds: 500),
    this.spacing = 12,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  final double? height;
  final double viewportFraction;
  final Duration autoScrollDuration;
  final Duration animationDuration;
  final double spacing;

  @override
  State<AutoScrollCarousel> createState() => _AutoScrollCarouselState();
}

class _AutoScrollCarouselState extends State<AutoScrollCarousel> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        PageController(viewportFraction: widget.viewportFraction);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    Future.doWhile(() async {
      await Future.delayed(widget.autoScrollDuration);

      if (!mounted || widget.itemCount <= 1) return false;

      _currentIndex = (_currentIndex + 1) % widget.itemCount;

      _controller.animateToPage(
        _currentIndex,
        duration: widget.animationDuration,
        curve: Curves.easeOut,
      );

      return true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ✅ THIS WAS MISSING
  @override
  Widget build(BuildContext context) {
    final pageView = PageView.builder(
      controller: _controller,
      itemCount: widget.itemCount,
      onPageChanged: (i) => _currentIndex = i,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(right: widget.spacing),
          child: widget.itemBuilder(context, index),
        );
      },
    );

    if (widget.height != null) {
      return SizedBox(
        height: widget.height,
        child: pageView,
      );
    }

    return pageView;
  }
}
