import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/side_drawer/about_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/bible_book_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/event_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/favorite_verses_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/members_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/prayer_request_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/settings_screen.dart';

enum DrawerMenuItem {
  events,
  prayerRequest,
  members,
  favorites,
  holyBible,
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
        return 'Members';
      case DrawerMenuItem.holyBible:
        return 'Holy Bible';
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
      case DrawerMenuItem.holyBible:
        return Icons.book_online_outlined;
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
      case DrawerMenuItem.holyBible:
        return BibleBookScreen();
      case DrawerMenuItem.settings:
        return const SettingsScreen();
    }
  }
}