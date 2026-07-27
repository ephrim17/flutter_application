import 'package:cloud_firestore/cloud_firestore.dart';

class PrayerRequest {
  final String id;
  final String title;
  final String description;
  final String userId;
  final bool isAnonymous;
  final DateTime expiryDate;
  final bool isGlobal;
  final String sourceChurchId;
  final String sourcePrayerId;
  final String sourceChurchName;

  PrayerRequest({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
    required this.isAnonymous,
    required this.expiryDate,
    this.isGlobal = false,
    this.sourceChurchId = '',
    this.sourcePrayerId = '',
    this.sourceChurchName = '',
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
      expiryDate: expiryValue is Timestamp
          ? expiryValue.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      isGlobal: data['isGlobal'] == true,
      sourceChurchId: data['sourceChurchId'] ?? data['churchId'] ?? '',
      sourcePrayerId: data['sourcePrayerId'] ?? '',
      sourceChurchName: data['sourceChurchName'] ?? '',
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
      'isGlobal': isGlobal,
      if (sourceChurchId.isNotEmpty) 'sourceChurchId': sourceChurchId,
      if (sourcePrayerId.isNotEmpty) 'sourcePrayerId': sourcePrayerId,
      if (sourceChurchName.isNotEmpty) 'sourceChurchName': sourceChurchName,
    };
  }
}
