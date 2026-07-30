import 'package:cloud_firestore/cloud_firestore.dart';

class Article {
  final String id;
  final String title;
  final String description;
  final String content;
  final String createdByUid;
  final String createdByName;
  final String createdByEmail;
  final String createdByProfilePhotoUrl;
  final DateTime? createdAt;

  Article({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    this.createdByUid = '',
    this.createdByName = '',
    this.createdByEmail = '',
    this.createdByProfilePhotoUrl = '',
    this.createdAt,
  });

  factory Article.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawCreatedBy = data['createdBy'];
    final createdBy = rawCreatedBy is Map
        ? Map<String, dynamic>.from(rawCreatedBy)
        : const <String, dynamic>{};
    final rawCreatedAt = data['createdAt'];

    return Article(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      content: (data['content'] ?? '').toString(),
      createdByUid: (createdBy['uid'] ?? '').toString().trim(),
      createdByName: (createdBy['name'] ?? '').toString().trim(),
      createdByEmail: (createdBy['email'] ?? '').toString().trim(),
      createdByProfilePhotoUrl:
          (createdBy['profilePhotoUrl'] ?? '').toString().trim(),
      createdAt: rawCreatedAt is Timestamp
          ? rawCreatedAt.toDate()
          : rawCreatedAt is DateTime
              ? rawCreatedAt
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'content': content,
      if (createdByUid.isNotEmpty ||
          createdByName.isNotEmpty ||
          createdByEmail.isNotEmpty ||
          createdByProfilePhotoUrl.isNotEmpty)
        'createdBy': {
          'uid': createdByUid,
          'name': createdByName,
          'email': createdByEmail,
          'profilePhotoUrl': createdByProfilePhotoUrl,
        },
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }
}
