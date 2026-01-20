import 'package:cloud_firestore/cloud_firestore.dart';

class DailyVerse {
  final String id; // docId
  final String title;
  final String description;

  const DailyVerse({
    required this.id,
    required this.title,
    required this.description,
  });

  DailyVerse copyWith({
    String? id,
    String? title,
    String? description,
  }) {
    return DailyVerse(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }

  /// For writing to Firestore (id is not stored inside fields)
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description
      };

  /// For reading from Firestore
  static DailyVerse fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return DailyVerse(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      description: (data['description'] ?? '') as String,
    );
  }
}
