import 'package:flutter/material.dart';

/// Width at which a pointer, rather than a thumb, is the likely input and
/// the carousel arrows are worth their space.
///
/// Below it there are no arrows at all, so the touch layout is unchanged:
/// a finger has the swipe, and the dots are tappable everywhere.
const double carouselArrowBreakpoint = 700;

/// One of the two nudge buttons a pointer uses to move a carousel on.
///
/// Shared by `AutoScrollCarousel` and `SnappingCardRail`, which are two
/// different widgets — a `PageView` and a scroll view — that a reader has
/// no way of telling apart and should not have to.
///
/// Null [onTap] means there is nothing that way, and the arrow dims rather
/// than disappearing: a control that comes and goes is harder to aim at
/// than one that greys out.
class CarouselArrow extends StatelessWidget {
  const CarouselArrow({
    super.key,
    required this.alignment,
    required this.icon,
    required this.onTap,
  });

  final Alignment alignment;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Material(
          color: colors.surface.withValues(alpha: enabled ? 0.92 : 0.5),
          shape: const CircleBorder(),
          elevation: enabled ? 2 : 0,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                icon,
                size: 24,
                color: enabled
                    ? colors.onSurface
                    : colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
