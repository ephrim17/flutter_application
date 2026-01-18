import 'package:cloud_firestore/cloud_firestore.dart';

class PrayerRequest {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime createdAt;

  PrayerRequest({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  factory PrayerRequest.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return PrayerRequest(
      id: doc.id,
      userId: data['userId'],
      title: data['title'],
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
