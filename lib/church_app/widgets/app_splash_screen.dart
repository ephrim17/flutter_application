import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key, this.size = 240});

  final double size;

  static const assetPath = 'assets/lottie/splashScreen.json';

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _titleEntrance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _titleEntrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.42, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Church Tree splash animation',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: Lottie.asset(
              AppSplashScreen.assetPath,
              repeat: true,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Lottie splash load failed: $error');
                return Center(
                  child: SizedBox.square(
                    dimension: widget.size * 0.28,
                    child: const CircularProgressIndicator(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          AppLogoText(controller: _controller, titleEntrance: _titleEntrance),
        ],
      ),
    );
  }
}

class AppLogoText extends StatefulWidget {
  const AppLogoText({
    super.key,
    this.controller,
    this.titleEntrance,
    this.loop = true,
  });

  final AnimationController? controller;
  final Animation<double>? titleEntrance;
  final bool loop;

  @override
  State<AppLogoText> createState() => _AppLogoTextState();
}

class _AppLogoTextState extends State<AppLogoText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _titleEntrance;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _ownsController = false;
      _controller = widget.controller!;
      _titleEntrance = widget.titleEntrance ??
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 0.42, curve: Curves.easeOutCubic),
          );
    } else {
      _ownsController = true;
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      );
      if (widget.loop) {
        _controller.repeat(reverse: true);
      } else {
        _controller.addStatusListener(_handleStatus);
        _controller.forward();
      }
      _titleEntrance = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.42, curve: Curves.easeOutCubic),
      );
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _controller.reverse();
    } else if (status == AnimationStatus.dismissed) {
      _controller.removeStatusListener(_handleStatus);
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final entrance = _titleEntrance.value;
        final pulse = 1 + (_controller.value * 0.025);
    
        return Opacity(
          opacity: entrance,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - entrance)),
            child: Transform.scale(
              scale: pulse,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  final sweep = (_controller.value * 2) - 0.5;
                  return LinearGradient(
                    begin: Alignment(-1 + sweep, -0.7),
                    end: Alignment(1 + sweep, 0.7),
                    colors: const [
                      Color(0xFF2F7D3F),
                      Color(0xFF9DD67A),
                      Color(0xFFFFFFFF),
                      Color(0xFF3C9B52),
                      Color(0xFF1D5D34),
                    ],
                    stops: const [0, 0.28, 0.5, 0.72, 1],
                  ).createShader(bounds);
                },
                child: const Text(
                  'Church Tree',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
