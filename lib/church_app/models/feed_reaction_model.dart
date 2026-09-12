import 'package:cloud_firestore/cloud_firestore.dart';

/// The fixed emoji set offered by the quick-reaction picker, in display
/// order — matches the set already in production use for this feature.
const List<String> feedReactionEmojiChoices = ['🙏', '❤️', '🤍', '👍', '🎉'];

/// One person's reaction to a feed post — `.../feeds/{postId}/reactions/{uid}`
/// or `.../globalFeeds/{postId}/reactions/{uid}`, doc id == uid so reacting
/// again just overwrites the previous emoji. Name/phone/photo are
/// denormalized onto the doc at write time (matching how `FeedPost` itself
/// denormalizes its author), so the "who reacted" sheet needs no extra reads.
class FeedReaction {
  final String uid;
  final String emoji;
  final String name;
  final String phone;
  final String? photoUrl;
  final DateTime? createdAt;

  const FeedReaction({
    required this.uid,
    required this.emoji,
    required this.name,
    this.phone = '',
    this.photoUrl,
    this.createdAt,
  });

  factory FeedReaction.fromFirestore(String uid, Map<String, dynamic> data) {
    return FeedReaction(
      uid: uid,
      emoji: (data['emoji'] ?? '').toString().trim(),
      name: (data['name'] ?? '').toString().trim(),
      phone: (data['phone'] ?? '').toString().trim(),
      photoUrl: (data['photoUrl'] ?? '').toString().trim().isEmpty
          ? null
          : data['photoUrl'].toString().trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'emoji': emoji,
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
