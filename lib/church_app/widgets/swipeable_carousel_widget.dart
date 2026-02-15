import 'package:flutter/material.dart';

class SwipeableCardCarousel extends StatefulWidget {
  final List<Widget> items;
  final double height;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const SwipeableCardCarousel({
    Key? key,
    required this.items,
    this.height = 220,
    this.padding,
    this.borderRadius = 20,
  }) : super(key: key);

  @override
  State<SwipeableCardCarousel> createState() =>
      _SwipeableCardCarouselState();
}

class _SwipeableCardCarouselState
    extends State<SwipeableCardCarousel> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: widget.padding ??
                    const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(widget.borderRadius),
                  child: widget.items[index],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        /// Dot Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.items.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin:
                  const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: _currentIndex == index ? 18 : 8,
              decoration: BoxDecoration(
                color: _currentIndex == index
                    ? Colors.black87
                    : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
