import 'package:cloud_firestore/cloud_firestore.dart';

class FeedPost {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String? churchId;
  final String? churchName;
  final String? churchPastorName;
  final bool sharePersonalDetails;
  final String? userCategory;
  final String? userAddress;
  final String? userEmail;
  final String? userPhone;
  final DateTime? userDob;
  final String title;
  final String description;
  final List<String> hashtags;
  final bool isPinned;
  final DateTime? pinnedAt;
  final String? imageUrl;
  final List<String> imageUrls;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  FeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    this.churchId,
    this.churchName,
    this.churchPastorName,
    this.sharePersonalDetails = false,
    this.userCategory,
    this.userAddress,
    this.userEmail,
    this.userPhone,
    this.userDob,
    required this.title,
    required this.description,
    this.hashtags = const [],
    this.isPinned = false,
    this.pinnedAt,
    this.imageUrl,
    this.imageUrls = const [],
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
  });

  factory FeedPost.fromJson(String id, Map<String, dynamic> json) {
    return FeedPost(
      id: id,
      userId: json['userId'],
      userName: json['userName'],
      userPhoto: json['userPhoto'],
      churchId: json['churchId'],
      churchName: json['churchName'],
      churchPastorName: json['churchPastorName'],
      sharePersonalDetails: json['sharePersonalDetails'] ?? false,
      userCategory: json['userCategory'],
      userAddress: json['userAddress'],
      userEmail: json['userEmail'],
      userPhone: json['userPhone'],
      userDob: _parseDate(json['userDob']),
      title: json['title'],
      description: json['description'],
      hashtags: _parseStringList(json['hashtags']),
      isPinned: json['isPinned'] ?? false,
      pinnedAt: _parseDate(json['pinnedAt']),
      imageUrl: json['imageUrl'],
      imageUrls: _parseImageUrls(json),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is! Iterable) return const [];
    return value
        .map((item) => item.toString().trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _parseImageUrls(Map<String, dynamic> json) {
    final urls = (json['imageUrls'] as Iterable?)
            ?.map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    if (urls.isNotEmpty) return urls;
    final legacyUrl = (json['imageUrl'] ?? '').toString().trim();
    return legacyUrl.isEmpty ? const [] : [legacyUrl];
  }
}
