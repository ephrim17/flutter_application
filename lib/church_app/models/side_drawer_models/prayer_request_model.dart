import 'package:cloud_firestore/cloud_firestore.dart';

int prayerDaysLeft(DateTime expiryDate, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final expiry = DateTime(
    expiryDate.year,
    expiryDate.month,
    expiryDate.day,
  );
  return expiry.difference(today).inDays.clamp(0, 999);
}

class PrayerRequest {
  final String id;
  final String title;
  final String description;
  final String userId;
  final bool isAnonymous;
  final bool visibleToChurchMembers;
  final DateTime expiryDate;

  PrayerRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
    required this.isAnonymous,
    this.visibleToChurchMembers = false,
    required this.expiryDate,
  });

  /// 🔹 For .withConverter()
  factory PrayerRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final expiryValue = data['expiryDate'];

    return PrayerRequest(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      userId: data['userId'] ?? '',
      isAnonymous: data['isAnonymous'] ?? false,
      visibleToChurchMembers: data['visibleToChurchMembers'] == true,
      expiryDate: expiryValue is Timestamp
          ? expiryValue.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// 🔹 REQUIRED for .withConverter()
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'userId': userId,
      'isAnonymous': isAnonymous,
      'visibleToChurchMembers': visibleToChurchMembers,
      'expiryDate': Timestamp.fromDate(expiryDate),
    };
  }
}
