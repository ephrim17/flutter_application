import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

/// Collapses [appBar] out of view (Instagram-style) rather than pushing it
/// off-screen — the reserved slot never resizes, only the visible slice does,
/// so hiding/showing never triggers a layout jump in the body below.
class HideableAppBar extends StatelessWidget {
  const HideableAppBar({
    super.key,
    required this.visible,
    required this.appBar,
  });

  final bool visible;
  final PreferredSizeWidget appBar;

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        appBar.preferredSize.height + MediaQuery.of(context).padding.top;

    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: visible ? maxHeight : 0,
        alignment: Alignment.topCenter,
        child: OverflowBox(
          minHeight: maxHeight,
          maxHeight: maxHeight,
          alignment: Alignment.topCenter,
          child: appBar,
        ),
      ),
    );
  }
}

/// Shared scroll-direction-to-visibility logic for [HideableAppBar]: call
/// from a `NotificationListener<ScrollNotification>.onNotification` and feed
/// the result into a `setState`-backed `bool` visibility flag.
///
/// [onChanged] always runs in a post-frame callback, never synchronously —
/// a `ScrollEndNotification` can be dispatched from inside
/// `RenderViewport.performLayout` itself (a drag getting cancelled as
/// content dimensions change mid-layout), and calling `setState()`
/// synchronously from there schedules a new build while the current frame
/// is still being built, which throws ("Build scheduled during frame").
/// Because it's deferred, [onChanged] MUST guard with `if (mounted)` before
/// calling `setState` — the widget can be disposed before the post-frame
/// callback runs.
bool computeHideableAppBarVisibility({
  required ScrollNotification notification,
  required bool currentlyVisible,
  required ValueChanged<bool> onChanged,
}) {
  void schedule(bool visible) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(visible));
  }

  if (notification is UserScrollNotification) {
    if (notification.direction == ScrollDirection.reverse) {
      if (currentlyVisible) schedule(false);
    } else if (notification.direction == ScrollDirection.forward) {
      if (!currentlyVisible) schedule(true);
    }
  } else if (notification is ScrollUpdateNotification ||
      notification is ScrollEndNotification) {
    if (notification.metrics.pixels <= 0 && !currentlyVisible) {
      schedule(true);
    }
  }
  return false;
}
