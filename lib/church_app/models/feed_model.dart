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
  // The first image's raw pixel dimensions, captured at upload time so the
  // feed can size its card to the image's real aspect ratio before the
  // image itself has even downloaded — avoiding both a layout jump and a
  // forced square crop. Null for posts uploaded before this existed.
  final double? imageWidth;
  final double? imageHeight;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  /// Reaction counts by emoji (e.g. {'🙏': 9, '❤️': 6}) and their total —
  /// written only by `onChurchFeedReactionWrite`/`onGlobalFeedReactionWrite`
  /// (Cloud Functions, Admin SDK) from the post's `reactions` subcollection.
  /// The client never writes these fields directly; see
  /// `FeedReactionRepository` for the per-user reaction doc it does write.
  final Map<String, int> reactionSummary;
  final int reactionTotal;

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
    this.imageWidth,
    this.imageHeight,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    this.reactionSummary = const {},
    this.reactionTotal = 0,
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
      imageWidth: (json['imageWidth'] as num?)?.toDouble(),
      imageHeight: (json['imageHeight'] as num?)?.toDouble(),
      createdAt: _parseDate(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      reactionSummary: _parseReactionSummary(json['reactionSummary']),
      reactionTotal: (json['reactionTotal'] as num?)?.toInt() ?? 0,
    );
  }

  static Map<String, int> _parseReactionSummary(dynamic value) {
    if (value is! Map) return const {};
    final result = <String, int>{};
    value.forEach((key, rawCount) {
      final emoji = key.toString();
      final parsed = (rawCount as num?)?.toInt() ?? 0;
      if (emoji.isNotEmpty && parsed > 0) result[emoji] = parsed;
    });
    return result;
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

  /// Clamped to the same portrait/landscape range Instagram uses, or null
  /// if this post predates dimension capture — callers fall back to a
  /// fixed ratio in that case rather than guessing.
  double? get clampedImageAspectRatio {
    final width = imageWidth;
    final height = imageHeight;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return (width / height).clamp(
      feedImageMinAspectRatio,
      feedImageMaxAspectRatio,
    );
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
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      createdAt: createdAt,
      likeCount: likeCount,
      commentCount: commentCount,
      reactionSummary: reactionSummary,
      reactionTotal: reactionTotal,
    );
  }
}

/// Instagram settled on this same range: portrait 4:5 up to landscape
/// 1.91:1. Anything inside it renders uncropped; only the rare
/// extremely-tall or extremely-wide photo gets clamped (and cropped) to fit.
const double feedImageMinAspectRatio = 4 / 5;
const double feedImageMaxAspectRatio = 1.91;
