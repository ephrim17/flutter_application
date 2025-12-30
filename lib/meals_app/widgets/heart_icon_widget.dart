import 'package:flutter/material.dart';

class HeartIconButton extends StatefulWidget {
  const HeartIconButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    required this.iconName,
  });

  final bool isFavorite; 
  final VoidCallback onToggle;
  final IconData iconName;

  @override
  State<HeartIconButton> createState() => _HeartIconButtonState();
}

class _HeartIconButtonState extends State<HeartIconButton> {
  double _scale = 1.0;
  bool _tapped = false;

  void _animatePop() async {
    setState(() => _scale = 1.5);
    await Future.delayed(const Duration(milliseconds: 150));
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      child: IconButton(
        onPressed: () {
          if (!_tapped) {
            _tapped = true;
            _animatePop();
            widget.onToggle();
            Future.delayed(const Duration(milliseconds: 200), () {
              _tapped = false;
            });
          }
        },
        icon: Icon(widget.iconName),
        color: Colors.redAccent,
      ),
    );
  }
}