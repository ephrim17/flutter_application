import 'package:flutter/material.dart';

extension EventTypeAssetX on EventType {
  String get imageAsset {
    switch (this) {
      case EventType.family:
        return 'assets/images/family.jpg';
      case EventType.kids:
        return 'assets/images/kids.jpg';
      case EventType.youth:
        return 'assets/images/youth.jpg';
    }
  }

  Color get badgeColor {
    switch (this) {
      case EventType.family:
        return const Color.fromARGB(255, 226, 80, 237);
      case EventType.kids:
        return Colors.green;
      case EventType.youth:
        return Colors.blue;
    }
  }

  String get label {
    switch (this) {
      case EventType.family:
        return 'FAMILY';
      case EventType.kids:
        return 'KIDS';
      case EventType.youth:
        return 'YOUTH';
    }
  }
}

enum EventType {
  family,
  kids,
  youth;

  static const firestoreKey = {
    family: 'family',
    kids: 'kids',
    youth: 'youth',
  };
}

extension EventTypeX on EventType {
  static EventType fromString(String? value) {
    if (value == null) return EventType.family;

    return EventType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EventType.family,
    );
  }
}