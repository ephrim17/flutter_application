import 'package:cloud_firestore/cloud_firestore.dart';

class LiveChurchConfig {
  const LiveChurchConfig({
    required this.youtubeChannelId,
    required this.enabled,
    required this.notifyWhenLive,
  });

  final String youtubeChannelId;
  final bool enabled;
  final bool notifyWhenLive;

  factory LiveChurchConfig.fromMap(Map<String, dynamic>? data) {
    return LiveChurchConfig(
      youtubeChannelId: (data?['youtubeChannelId'] ?? '').toString(),
      enabled: data?['enabled'] == true,
      notifyWhenLive: data?['notifyWhenLive'] == true,
    );
  }
}

class LiveChurchStatus {
  const LiveChurchStatus({
    required this.isLive,
    required this.canEmbed,
    required this.videoId,
    required this.title,
    this.startedAt,
  });

  final bool isLive;
  final bool canEmbed;
  final String videoId;
  final String title;
  final DateTime? startedAt;

  bool get canPlay => isLive && videoId.trim().isNotEmpty;

  factory LiveChurchStatus.fromMap(Map<String, dynamic>? data) {
    return LiveChurchStatus(
      isLive: data?['isLive'] == true,
      canEmbed: data?['canEmbed'] != false,
      videoId: (data?['videoId'] ?? '').toString(),
      title: (data?['title'] ?? '').toString(),
      startedAt: (data?['startedAt'] as Timestamp?)?.toDate(),
    );
  }
}
