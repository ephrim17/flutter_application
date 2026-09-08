import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';

class LightningGradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  const LightningGradientText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.visible,
    this.textAlign = TextAlign.start,
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
        maxLines: maxLines,
        softWrap: true,
        overflow: overflow,
        textAlign: textAlign,
        style: style,
      ),
    );
  }

  Shader _lightningShader(Rect bounds, BuildContext context) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.primary // deep blue // orange strike
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

class ChurchAppBarBrandTitle extends StatelessWidget {
  const ChurchAppBarBrandTitle({
    super.key,
    required this.text,
    required this.logo,
    this.maxWidth,
  });

  final String text;
  final String logo;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? MediaQuery.of(context).size.width * 0.68,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChurchLogoAvatar(logo: logo, size: 30),
          const SizedBox(width: 10),
          Flexible(
            child: LightningGradientText(
              text: text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: theme.textTheme.titleLarge!.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
