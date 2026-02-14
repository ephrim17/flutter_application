import 'package:cloud_firestore/cloud_firestore.dart';

class PrayerRequest {
  final String id;
  final String title;
  final String description;
  final String userId;
  final bool isAnonymous;
  final DateTime expiryDate;

  PrayerRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
    required this.isAnonymous,
    required this.expiryDate,
  });

  factory PrayerRequest.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return PrayerRequest(
      id: doc.id,
      title: data['title'],
      description: data['description'],
      userId: data['userId'] ?? '',
      isAnonymous: data['isAnonymous'] ?? false,
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
    );
  }
}
