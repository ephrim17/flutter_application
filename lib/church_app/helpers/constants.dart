import 'package:flutter/material.dart';

double spacingForOrder(int order) {
  return 15;
}

//cardHeights
double cardHeight(String id) {
  if (id == "announcements") return 280; 
  if (id == "events") return 200; 
  if (id == "pastor") return 220; 
  if (id == "promise") return 400; 
  if (id == "dailyVerse") return 220;
  if (id == "eventsFullListCard") return 250;
  return 120;
}

BoxDecoration carouselBoxDecoration(BuildContext context) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(cornerRadius),
    border: Border.all(
      color: const Color.fromARGB(31, 169, 158, 158).withAlpha(5),
    ),
    color: Theme.of(context).cardTheme.color,
    boxShadow: const [
      BoxShadow(
        color: Color(0x0D000000), // ~5% opacity
        blurRadius: 18,           // higher blur = softer edge
        spreadRadius: 0,          // IMPORTANT: no spread
        offset: Offset.zero,      // all sides
      ),
    ],
  );
}


double cornerRadius = 28.0;

String appName = "My Church";
String appTagline = "Connecting Faith and Community";

extension HexColor on String {
  Color toColor() {
    final hex = replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}