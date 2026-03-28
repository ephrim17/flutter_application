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
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? MediaQuery.of(context).size.width * 0.68,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            left: 14,
            child: _BrandAccentDot(
              size: 10,
              color: secondary.withValues(alpha: 0.75),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 8,
            child: _BrandAccentDot(
              size: 8,
              color: primary.withValues(alpha: 0.65),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primary.withValues(alpha: 0.10),
                  secondary.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: primary.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChurchLogoAvatar(
                  logo: logo,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 2),
                      LightningGradientText(
                        text: text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall!.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandAccentDot extends StatelessWidget {
  const _BrandAccentDot({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
