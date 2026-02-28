import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';

class AnimatedLiveItUpCard extends StatefulWidget {
  const AnimatedLiveItUpCard({super.key});

  @override
  State<AnimatedLiveItUpCard> createState() => _AnimatedLiveItUpCardState();
}

class _AnimatedLiveItUpCardState extends State<AnimatedLiveItUpCard>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _heartController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();

    /// Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    /// Heart pulse animation
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _heartScale = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: Curves.easeInOut,
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          //decoration: carouselBoxDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// Main Title
              Text(
                "Live\nit up!",
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  color: Colors.grey[800],
                ),
              ),

              const SizedBox(height: 40),

              /// Footer
              SizedBox(
                width: double.infinity,
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                    children: [
                      const TextSpan(text: "Developed with "),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: ScaleTransition(
                          scale: _heartScale,
                          child: const Icon(
                            Icons.favorite,
                            color: Color(0xFFE2556E),
                            size: 20,
                          ),
                        ),
                      ),
                      const TextSpan(text: " in Trivandrum, India"),
                    ],
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
