import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/decorated_scripture_card_widget.dart';

class PraiseTheLordCard extends StatefulWidget {
  const PraiseTheLordCard({super.key});

  @override
  State<PraiseTheLordCard> createState() => _PraiseTheLordCardState();
}

class _PraiseTheLordCardState extends State<PraiseTheLordCard>
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
    final theme = Theme.of(context);
    final titleColor = theme.textTheme.headlineLarge?.color ?? Colors.white;
    final subtitleColor = theme.textTheme.bodySmall?.color ?? Colors.white70;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: DecoratedScriptureCard(
                width: constraints.maxWidth - 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Praise \nThe Lord",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          color: titleColor,
                        ),
                      ),

                      const SizedBox(height: 36),

                      SizedBox(
                        width: double.infinity,
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 18,
                              color: subtitleColor,
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
                              const TextSpan(text: " from Trivandrum, India"),
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
          },
        ),
      ),
    );
  }
}
