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
    showDragHandle: false,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    useSafeArea: useSafeArea ?? false,
    builder: (context) {
      final child = _unwrapExistingFractionalSheet(builder(context));
      final shouldShowGrabHandle = showDragHandle ?? true;
      final handleLaneHeight = shouldShowGrabHandle ? 36.0 : 0.0;
      return FractionallySizedBox(
        heightFactor: heightFactor,
        child: Stack(
          children: [
            Positioned.fill(
              top: handleLaneHeight,
              child: child,
            ),
            if (shouldShowGrabHandle)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                      ),
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
