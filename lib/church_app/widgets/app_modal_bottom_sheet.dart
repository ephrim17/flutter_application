import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;

Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool isScrollControlled = true,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  bool? useSafeArea,
  double heightFactor = 0.9,
}) {
  return material.showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    elevation: elevation,
    shape: shape,
    clipBehavior: clipBehavior,
    constraints: constraints,
    barrierColor: barrierColor,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle ?? false,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    useSafeArea: useSafeArea ?? false,
    builder: (context) {
      final child = _unwrapExistingFractionalSheet(builder(context));
      const closeButtonLaneHeight = 72.0;
      return FractionallySizedBox(
        heightFactor: heightFactor,
        child: Stack(
          children: [
            Positioned.fill(
              top: closeButtonLaneHeight,
              child: child,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                minimum: const EdgeInsets.only(top: 4, right: 4),
                child: Material(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.92),
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _unwrapExistingFractionalSheet(Widget child) {
  if (child is FractionallySizedBox && child.child != null) {
    return child.child!;
  }
  return child;
}
