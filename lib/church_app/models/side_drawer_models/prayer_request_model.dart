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

  /// 🔹 For .withConverter()
  factory PrayerRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    return PrayerRequest(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      userId: data['userId'] ?? '',
      isAnonymous: data['isAnonymous'] ?? false,
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
    );
  }

  /// 🔹 REQUIRED for .withConverter()
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'userId': userId,
      'isAnonymous': isAnonymous,
      'expiryDate': Timestamp.fromDate(expiryDate),
    };
  }
}