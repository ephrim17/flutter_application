/// The vertical rhythm every For You section follows.
///
/// Each section used to set its own top/bottom padding and its own
/// header-to-card gap on top of the spacer the screen already inserts
/// between sections. The result drifted: Articles had no gap at all between
/// its heading and its card while Featured had ten, and the space before
/// one heading was not the space before the next. These four constants are
/// the whole contract — a section contributes no vertical padding of its
/// own, so the gaps between sections are identical by construction rather
/// than by each section happening to agree.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Between the end of one section and the start of the next. Applied once,
/// by `ForYouScreen`, never by a section.
const double forYouSectionGap = 24;

/// A section's heading to the first thing under it — its card, or its
/// subtitle when it has one.
const double forYouHeaderGap = 12;

/// A heading to its subtitle line. Tighter than [forYouHeaderGap] so the
/// subtitle reads as part of the heading rather than as content.
const double forYouSubtitleGap = 4;

/// Between two cards stacked inside the same section.
const double forYouCardGap = 12;

/// The side gutter every section's content sits in.
const double forYouSidePadding = 16;

/// Height of a fixed-height carousel tile (the Circles rail). Cards that can
/// size to their own content do not use this.
const double forYouPrimaryCardHeight = 264;

/// The gap above a section, which disappears when that section renders
/// nothing.
///
/// A plain `SizedBox(height: forYouSectionGap)` placed before a section is
/// emitted whether or not the section draws anything, and several For You
/// sections legitimately render `SizedBox.shrink()` when they have no
/// content — no learning modules published, no reflection for today. Each
/// of those left a 24dp band of empty page behind it. On a real church that
/// stacked up: the space between the Daily Verse card and the "Pray for
/// others" heading measured 104dp against the 33dp between Pray and
/// Featured, because two silent sections sat in between.
///
/// This measures the child first and only reserves the gap when the child
/// has height, so an empty section costs exactly nothing.
class ForYouSectionSpacing extends SingleChildRenderObjectWidget {
  const ForYouSectionSpacing({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderForYouSectionSpacing();
}

class RenderForYouSectionSpacing extends RenderShiftedBox {
  RenderForYouSectionSpacing() : super(null);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    child.layout(constraints, parentUsesSize: true);
    final childData = child.parentData! as BoxParentData;

    if (child.size.height <= 0) {
      // Nothing was drawn, so nothing is separated from anything.
      childData.offset = Offset.zero;
      size = constraints.constrain(Size(child.size.width, 0));
      return;
    }

    childData.offset = const Offset(0, forYouSectionGap);
    size = constraints.constrain(
      Size(child.size.width, child.size.height + forYouSectionGap),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final child = this.child;
    if (child == null) return 0;
    final height = child.getMinIntrinsicHeight(width);
    return height <= 0 ? 0 : height + forYouSectionGap;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final child = this.child;
    if (child == null) return 0;
    final height = child.getMaxIntrinsicHeight(width);
    return height <= 0 ? 0 : height + forYouSectionGap;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final childSize = child.getDryLayout(constraints);
    if (childSize.height <= 0) {
      return constraints.constrain(Size(childSize.width, 0));
    }
    return constraints.constrain(
      Size(childSize.width, childSize.height + forYouSectionGap),
    );
  }
}

/// Marks a section that already spaces its own parts, so the page does not
/// add the between-sections gap on top.
///
/// Only a section that is really a group of sibling sections needs this —
/// Faith Engagement stacks Daily Faith Loop and Circles, each with its own
/// heading and its own [ForYouSectionSpacing]. A marker rather than a flag
/// on `MasterSection`, because the sections implement that interface rather
/// than extending it, so a default would have to be repeated in all eight.
class ForYouSelfSpaced extends StatelessWidget {
  const ForYouSelfSpaced({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
