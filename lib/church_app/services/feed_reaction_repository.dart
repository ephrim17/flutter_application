import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/feed_reaction_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

/// Reactions on one feed post — `.../feeds/{postId}/reactions/{uid}`
/// (church-scoped, [churchId] set) or `globalFeeds/{postId}/reactions/{uid}`
/// ([churchId] null/empty). The parent post's `reactionSummary`/
/// `reactionTotal` aggregate is maintained server-side (Cloud Functions,
/// see `functions/src/feedReactions.ts`) — this repository only ever
/// touches the caller's own reaction doc.
class FeedReactionRepository {
  FeedReactionRepository({
    required this.firestore,
    required this.churchId,
    required this.postId,
  });

  final FirebaseFirestore firestore;
  final String? churchId;
  final String postId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirestorePaths.feedReactionsCollection(
        firestore,
        churchId: churchId,
        postId: postId,
      );

  Stream<List<FeedReaction>> watchAll() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => FeedReaction.fromFirestore(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Stream<FeedReaction?> watchMine(String uid) {
    return _collection.doc(uid).snapshots().map(
          (doc) => doc.exists
              ? FeedReaction.fromFirestore(doc.id, doc.data()!)
              : null,
        );
  }

  Future<void> setReaction({
    required String uid,
    required String emoji,
    required String name,
    String phone = '',
    String? photoUrl,
  }) {
    return _collection.doc(uid).set(
          FeedReaction(
            uid: uid,
            emoji: emoji,
            name: name,
            phone: phone,
            photoUrl: photoUrl,
          ).toMap(),
        );
  }

  Future<void> removeReaction(String uid) {
    return _collection.doc(uid).delete();
  }
}
