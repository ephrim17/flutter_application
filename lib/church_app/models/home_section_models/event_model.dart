import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/event_builders.dart';

class Event {
  final String id; // docId
  final String title;
  final String description;
  final String contact;
  final String location;
  final String timing;
  final EventType type;
  final bool isActive;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.contact,
    required this.location,
    required this.timing,
    required this.type,
    required this.isActive,
  });

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? contact,
    String? location,
    String? timing,
    EventType? type,
    bool? isActive,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      contact: contact ?? this.contact,
      location: location ?? this.location,
      timing: timing ?? this.timing,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive
    );
  }

  /// For writing to Firestore (id is not stored inside fields)
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'contact': contact,
        'location': location,
        'timing': timing,
        'type': type, 
        'isActive': isActive,
      };

  /// For reading from Firestore
  static Event fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return Event(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      contact: (data['contact'] ?? '') as String,
      location: (data['location'] ?? '') as String,
      timing: (data['timing'] ?? '') as String,
      type: EventTypeX.fromString(data['type'] as String?), 
      isActive: (data['isActive'] ?? true) as bool,
    );
  }
}
