import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'dart:ui';

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
    backgroundColor: Colors.transparent,
    elevation: elevation,
    shape: shape ?? const RoundedRectangleBorder(),
    clipBehavior: clipBehavior ?? Clip.none,
    constraints: constraints,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.38),
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
      final theme = Theme.of(context);
      final bottomSheetTheme = theme.bottomSheetTheme;
      final effectiveSheetColor = backgroundColor ??
          bottomSheetTheme.modalBackgroundColor ??
          bottomSheetTheme.backgroundColor ??
          theme.colorScheme.surface;
      final child = _unwrapExistingFractionalSheet(builder(context));
      final shouldShowGrabHandle = showDragHandle ?? true;
      final usesCustomSheetSurface = effectiveSheetColor == Colors.transparent;
      final handleLaneHeight =
          shouldShowGrabHandle && !usesCustomSheetSurface ? 36.0 : 0.0;
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: FractionallySizedBox(
            heightFactor: heightFactor,
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: usesCustomSheetSurface
                      ? Colors.transparent
                      : effectiveSheetColor.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(34),
                  border: usesCustomSheetSurface
                      ? null
                      : Border.all(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.08),
                        ),
                  boxShadow: usesCustomSheetSurface
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 38,
                            offset: const Offset(0, 18),
                          ),
                        ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      top: handleLaneHeight,
                      child: child,
                    ),
                    if (shouldShowGrabHandle)
                      Positioned(
                        top: 14,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Center(
                            child: Container(
                              width: 56,
                              height: 6,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.34),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
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
