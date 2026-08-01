import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id; // docId
  final String title;
  final String body;
  final bool isActive;
  final DateTime? expiryAt;
  final int priority;
  final String imageUrl;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.isActive,
    required this.expiryAt,
    required this.priority,
    required this.imageUrl,
  });

  Announcement copyWith({
    String? id,
    String? title,
    String? body,
    bool? isActive,
    DateTime? expiryAt,
    bool clearExpiryAt = false,
    int? priority,
    String? imageUrl,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      isActive: isActive ?? this.isActive,
      expiryAt: clearExpiryAt ? null : (expiryAt ?? this.expiryAt),
      priority: priority ?? this.priority,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// For writing to Firestore (id is not stored inside fields)
  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'isActive': isActive,
        'expiryAt': expiryAt == null ? null : Timestamp.fromDate(expiryAt!),
        'priority': priority,
        'imageUrl': imageUrl,
      };

  /// For reading from Firestore
  static Announcement fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return Announcement(
      id: doc.id,
      title: data['title']?.toString().trim() ?? '',
      body: data['body']?.toString().trim() ?? '',
      isActive: data['isActive'] != false,
      expiryAt: _parseDate(data['expiryAt']),
      imageUrl: data['imageUrl']?.toString().trim() ?? '',
      priority: (data['priority'] as num?)?.toInt() ?? 0,
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
