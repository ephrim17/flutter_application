import 'package:flutter/material.dart';

/// The widest a column of reading-and-tapping content is allowed to get.
///
/// This is not the Home/For You rule and deliberately differs from it. Those
/// pages are cards and pictures, which look right filling whatever window
/// they are given, so they have no cap at all. These are lists, forms and
/// tables — a member row whose name sits at the far left and whose toggle
/// sits 1,400px away at the far right is not using the width, it is making
/// the reader's eye travel for nothing, and it is easy to act on the wrong
/// row.
const double desktopReadableWidth = 1100.0;

/// Centres [child] and stops it growing past [desktopReadableWidth].
///
/// Below that width this changes nothing whatsoever — no centring, no
/// padding, no rebuild cost — so phones and tablets keep exactly the layout
/// they already have. It only engages on a window wide enough for the
/// stretch to be the problem.
class DesktopContentWidth extends StatelessWidget {
  const DesktopContentWidth({
    super.key,
    required this.child,
    this.maxWidth = desktopReadableWidth,
  });

  final Widget child;

  /// For the occasional screen that earns more room — a table with many
  /// columns, say — rather than making each one invent its own number.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// How many columns a grid of small stat tiles should use at [width].
///
/// A fixed `crossAxisCount` is what makes a summary grid look broken on a
/// desktop: two columns of tiles across 1,568px gives each one about 770 by
/// 440, an enormous box holding the word "16". Choosing the count from the
/// width keeps a tile roughly tile-sized at any size, and capping it at four
/// stops a very wide window spreading four figures into a thin line.
int statGridColumns(double width, {int itemCount = 4}) {
  final byWidth = width >= 1000
      ? 4
      : width >= 700
          ? 3
          : 2;
  return byWidth > itemCount ? itemCount : byWidth;
}

/// How tall a stat tile should be, given how many share the row.
///
/// Fewer columns means a wider tile, which needs no extra height; more
/// columns means a narrower one, where a two-line label needs the room.
double statGridTileHeight(int columns) => columns >= 4 ? 104 : 96;
