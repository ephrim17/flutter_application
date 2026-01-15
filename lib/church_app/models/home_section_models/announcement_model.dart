import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id; // docId
  final String title;
  final String body;

  // Optional scalable fields (add later easily)
  final bool isActive;
  final int priority;
  final bool isPinned;
  final DateTime startAt;
  final DateTime endAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.isActive,
    required this.priority,
    required this.isPinned,
    required this.startAt,
    required this.endAt,
  });

  Announcement copyWith({
    String? id,
    String? title,
    String? body,
    bool? isActive,
    int? priority,
    bool? isPinned,
    DateTime? startAt,
    DateTime? endAt,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      isPinned: isPinned ?? this.isPinned,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
    );
  }

  /// For writing to Firestore (id is not stored inside fields)
  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'isActive': isActive,
        'priority': priority,
        'isPinned': isPinned,
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
      };

  /// For reading from Firestore
  static Announcement fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    DateTime _dt(String key, {required DateTime fallback}) {
      final v = data[key];
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return fallback;
    }

    return Announcement(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      body: (data['body'] ?? '') as String,
      isActive: (data['isActive'] ?? true) as bool,
      priority: (data['priority'] ?? 0) as int,
      isPinned: (data['isPinned'] ?? false) as bool,
      startAt: _dt('startAt', fallback: DateTime.fromMillisecondsSinceEpoch(0)),
      endAt: _dt('endAt', fallback: DateTime(2100, 1, 1)),
    );
  }
}
