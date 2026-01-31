import 'package:cloud_firestore/cloud_firestore.dart';

class ShortModel {
  final String id;
  final String videoId;
  final String channelId;
  final String title;

  const ShortModel({
    required this.id,
    required this.videoId,
    required this.channelId,
    required this.title,
  });

  /// 🔄 Firestore → Model
  factory ShortModel.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return ShortModel(
      id: doc.id,
      videoId: data['videoId'] as String,
      channelId: data['channelId'] as String,
      title: data['title'] as String? ?? '',
    );
  }

  /// 🔼 Model → Firestore (for admin usage)
  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'channelId': channelId,
      'title': title,
    };
  }
}
