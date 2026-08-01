import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/event_builders.dart';

class Event {
  final String id; // docId
  final String title;
  final String description;
  final String contact;
  final String location;
  final String timing;
  final DateTime? startAt;
  final EventType type;
  final bool isActive;
  final DateTime? expiryAt;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.contact,
    required this.location,
    required this.timing,
    this.startAt,
    required this.type,
    required this.isActive,
    required this.expiryAt,
  });

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? contact,
    String? location,
    String? timing,
    DateTime? startAt,
    bool clearStartAt = false,
    EventType? type,
    bool? isActive,
    DateTime? expiryAt,
    bool clearExpiryAt = false,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      contact: contact ?? this.contact,
      location: location ?? this.location,
      timing: timing ?? this.timing,
      startAt: clearStartAt ? null : (startAt ?? this.startAt),
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      expiryAt: clearExpiryAt ? null : (expiryAt ?? this.expiryAt),
    );
  }

  /// For writing to Firestore (id is not stored inside fields)
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'contact': contact,
        'location': location,
        'timing': timing,
        'startAt': startAt == null ? null : Timestamp.fromDate(startAt!),
        'type': EventType.firestoreKey[type] ?? type.name,
        'isActive': isActive,
        'expiryAt': expiryAt == null ? null : Timestamp.fromDate(expiryAt!),
      };

  /// For reading from Firestore
  static Event fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return Event(
      id: doc.id,
      title: data['title']?.toString().trim() ?? '',
      description: data['description']?.toString().trim() ?? '',
      contact: data['contact']?.toString().trim() ?? '',
      location: data['location']?.toString().trim() ?? '',
      timing: data['timing']?.toString().trim() ?? '',
      startAt: _parseDate(data['startAt']),
      type: EventTypeX.fromString(data['type']?.toString()),
      isActive: data['isActive'] != false,
      expiryAt: _parseDate(data['expiryAt']),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
