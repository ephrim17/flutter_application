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
  double? heightFactor,
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
    showDragHandle: showDragHandle,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    useSafeArea: true,
    builder: (context) {
      final child = builder(context);
      if (heightFactor != null) {
        return FractionallySizedBox(
          heightFactor: heightFactor.clamp(0.1, 1.0),
          alignment: Alignment.bottomCenter,
          child: child,
        );
      }
      return child;
    },
  );
}
