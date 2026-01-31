import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/side_drawer/about_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/event_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/favorite_verses_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/members_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/prayer_request_screen.dart';

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

enum DrawerMenuItem {
  events,
  prayerRequest,
  members,
  favorites,
  about,
  settings,
}

extension DrawerMenuItemX on DrawerMenuItem {
  String get label {
    switch (this) {
      case DrawerMenuItem.events:
        return 'Events';
      case DrawerMenuItem.prayerRequest:
        return 'Prayer Request';
      case DrawerMenuItem.about:
        return 'About';
      case DrawerMenuItem.settings:
        return 'Settings';
      case DrawerMenuItem.favorites:
        return 'Favorites';
      case DrawerMenuItem.members:
        return 'members';
    }
  }

  IconData get icon {
    switch (this) {
      case DrawerMenuItem.events:
        return Icons.event;
      case DrawerMenuItem.prayerRequest:
        return Icons.volunteer_activism;
      case DrawerMenuItem.about:
        return Icons.info;
      case DrawerMenuItem.settings:
        return Icons.settings;
      case DrawerMenuItem.favorites:
        return Icons.favorite_rounded;
      case DrawerMenuItem.members:
        return Icons.people_sharp;
    }
  }

  Widget? get route {
    switch (this) {
      case DrawerMenuItem.events:
        return const EventsScreen();
      case DrawerMenuItem.prayerRequest:
        return const PrayerRequestScreen();
      case DrawerMenuItem.about:
        return const AboutScreen();
      case DrawerMenuItem.favorites:
        return FavoritesScreen();
      case DrawerMenuItem.members:
        return MembersScreen();
      case DrawerMenuItem.settings:
        return const Placeholder();
    }
  }

  //bool get isDestructive => this == DrawerMenuItem.logout;
}
