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
  bool showDragHandle = true,
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
    showDragHandle: false,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    useSafeArea: useSafeArea ?? true,
    builder: (context) {
      final mediaQuery = MediaQuery.of(context);
      final theme = Theme.of(context);
      final child = MediaQuery(
        data: mediaQuery.removeViewInsets(removeBottom: true),
        child: Builder(builder: builder),
      );
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                key: const ValueKey<String>('app-modal-drag-handle'),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.bottomSheetTheme.dragHandleColor ??
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          Flexible(child: child),
        ],
      );

      Widget sheet = content;
      if (heightFactor != null) {
        sheet = FractionallySizedBox(
          heightFactor: heightFactor.clamp(0.1, 1.0),
          alignment: Alignment.bottomCenter,
          child: content,
        );
      }

      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: sheet,
      );
    },
  );
}
