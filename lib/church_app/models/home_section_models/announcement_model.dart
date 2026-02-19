import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id; // docId
  final String title;
  final String body;
  final bool isActive;
  final int priority;
  final String imageUrl;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.isActive,
    required this.priority,
    required this.imageUrl,
  });

  Announcement copyWith({
    String? id,
    String? title,
    String? body,
    bool? isActive,
    int? priority,
    String? imageUrl,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// For writing to Firestore (id is not stored inside fields)
  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'isActive': isActive,
        'priority': priority,
        'imageUrl': imageUrl,
      };

  /// For reading from Firestore
  static Announcement fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return Announcement(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      body: (data['body'] ?? '') as String,
      isActive: (data['isActive'] ?? true) as bool,
      imageUrl: (data['imageUrl'] ?? '') as String,
      priority: (data['priority'] ?? 0) as int,
    );
  }
}
