import 'package:flutter/material.dart';

class SwipeUpHint extends StatefulWidget {
  const SwipeUpHint({super.key});

  @override
  State<SwipeUpHint> createState() => _SwipeUpHintState();
}

class _SwipeUpHintState extends State<SwipeUpHint>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _arrowOffset;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _arrowOffset = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _controller.stop();
    });
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: _controller.isAnimating ? 1 : 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _arrowOffset,
                    builder: (_, child) {
                      return Transform.translate(
                        offset: Offset(0, _arrowOffset.value),
                        child: child,
                      );
                    },
                    child: const Icon(
                      Icons.keyboard_arrow_up,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Swipe up to see more",
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
