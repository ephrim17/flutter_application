import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LightningGradientText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const LightningGradientText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) {
        return _lightningShader(bounds, context);
      },
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: GoogleFonts.lalezar(fontSize: 30, fontWeight: FontWeight.w600),
      ),
    );
  }

  Shader _lightningShader(Rect bounds, BuildContext context) {
    final colors = [
      Theme.of(context).primaryColor,
      Theme.of(context).colorScheme.secondary // deep blue // orange strike
    ];

    return LinearGradient(
      begin: const Alignment(-1.0, -0.8),
      end: const Alignment(3.0, 0.8),
      colors: colors,
      stops: const [
        0.25,
        0.25, // tight lightning band
      ],
      tileMode: TileMode.mirror, // ⚡ jagged repetition
    ).createShader(bounds);
  }
}
