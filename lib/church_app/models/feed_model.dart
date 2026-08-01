import 'package:cloud_firestore/cloud_firestore.dart';

class FeedPost {
  static const Duration editWindow = Duration(minutes: 30);

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
  final bool isGlobal;
  final String sourceChurchId;
  final String sourcePostId;
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
    this.isGlobal = false,
    this.sourceChurchId = '',
    this.sourcePostId = '',
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
      userId: _string(json['userId']),
      userName: _string(json['userName']),
      userPhoto: _nullableString(json['userPhoto']),
      churchId: _nullableString(json['churchId']),
      churchName: _nullableString(json['churchName']),
      churchPastorName: _nullableString(json['churchPastorName']),
      sharePersonalDetails: json['sharePersonalDetails'] == true,
      userCategory: _nullableString(json['userCategory']),
      userAddress: _nullableString(json['userAddress']),
      userEmail: _nullableString(json['userEmail']),
      userPhone: _nullableString(json['userPhone']),
      userDob: _parseDate(json['userDob']),
      title: _string(json['title']),
      description: _string(json['description']),
      hashtags: _parseStringList(json['hashtags']),
      isGlobal: json['isGlobal'] == true,
      sourceChurchId: (json['sourceChurchId'] ?? '').toString().trim(),
      sourcePostId: (json['sourcePostId'] ?? '').toString().trim(),
      isPinned: json['isPinned'] == true,
      pinnedAt: _parseDate(json['pinnedAt']),
      imageUrl: _nullableString(json['imageUrl']),
      imageUrls: _parseImageUrls(json),
      createdAt: _parseDate(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static String? _nullableString(dynamic value) {
    final result = _string(value);
    return result.isEmpty ? null : result;
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

  bool canEditAt(DateTime now) {
    return !now.isAfter(createdAt.add(editWindow));
  }

  FeedPost copyWith({
    String? id,
    bool? isGlobal,
    String? sourceChurchId,
    String? sourcePostId,
    bool? isPinned,
    DateTime? pinnedAt,
    bool clearPinnedAt = false,
  }) {
    return FeedPost(
      id: id ?? this.id,
      userId: userId,
      userName: userName,
      userPhoto: userPhoto,
      churchId: churchId,
      churchName: churchName,
      churchPastorName: churchPastorName,
      sharePersonalDetails: sharePersonalDetails,
      userCategory: userCategory,
      userAddress: userAddress,
      userEmail: userEmail,
      userPhone: userPhone,
      userDob: userDob,
      title: title,
      description: description,
      hashtags: hashtags,
      isGlobal: isGlobal ?? this.isGlobal,
      sourceChurchId: sourceChurchId ?? this.sourceChurchId,
      sourcePostId: sourcePostId ?? this.sourcePostId,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: clearPinnedAt ? null : (pinnedAt ?? this.pinnedAt),
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      createdAt: createdAt,
      likeCount: likeCount,
      commentCount: commentCount,
    );
  }
}
