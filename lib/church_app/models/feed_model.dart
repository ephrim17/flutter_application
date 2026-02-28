import 'package:cloud_firestore/cloud_firestore.dart';

class FeedPost {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  FeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.title,
    required this.description,
    this.imageUrl,
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
      title: json['title'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
    );
  }
}