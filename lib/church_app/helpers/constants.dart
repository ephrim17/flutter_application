import 'package:flutter/material.dart';

double spacingForOrder(int order) {
  return 20;
}

//cardHeights
double cardHeight(String id) {
  if (id == "announcements") return 120; 
  if (id == "events") return 120; 
  if (id == "pastor") return 220; 
  if (id == "dailyVerse") return 220;
  if (id == "eventsFullListCard") return 250;
  return 120;
}

BoxDecoration carouselBoxDecoration(BuildContext context,) {
    return BoxDecoration(
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(color: const Color.fromARGB(31, 169, 158, 158).withAlpha(05)),
        color: Theme.of(context).colorScheme.onInverseSurface
      );
}

double cornerRadius = 20.0;

String appName = "My Church";
String appTagline = "Connecting Faith and Community";

extension HexColor on String {
  Color toColor() {
    final hex = replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}