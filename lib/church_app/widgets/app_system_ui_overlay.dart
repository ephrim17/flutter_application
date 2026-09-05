import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Widget buildAppSystemUiOverlay(BuildContext context, Widget? child) {
  final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
  final overlayStyle = appSystemUiOverlayStyleFor(backgroundColor);

  SystemChrome.setSystemUIOverlayStyle(overlayStyle);

  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: overlayStyle,
    child: child ?? const SizedBox.shrink(),
  );
}

SystemUiOverlayStyle appSystemUiOverlayStyleFor(Color backgroundColor) {
  final usesDarkBackground = backgroundColor.computeLuminance() < 0.5;
  final iconBrightness =
      usesDarkBackground ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness:
        usesDarkBackground ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: backgroundColor,
    systemNavigationBarDividerColor: backgroundColor,
    systemNavigationBarIconBrightness: iconBrightness,
  );
}
