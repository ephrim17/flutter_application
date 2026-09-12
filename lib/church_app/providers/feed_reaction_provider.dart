import 'package:flutter_application/church_app/models/feed_reaction_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/feed_reaction_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identifies one feed post's reactions regardless of which feed it lives
/// in — [churchId] null/empty means `globalFeeds/{postId}`.
class FeedReactionTarget {
  const FeedReactionTarget({required this.churchId, required this.postId});

  final String? churchId;
  final String postId;

  @override
  bool operator ==(Object other) =>
      other is FeedReactionTarget &&
      other.churchId == churchId &&
      other.postId == postId;

  @override
  int get hashCode => Object.hash(churchId, postId);
}

FeedReactionRepository _repositoryFor(Ref ref, FeedReactionTarget target) {
  return FeedReactionRepository(
    firestore: ref.read(firestoreProvider),
    churchId: target.churchId,
    postId: target.postId,
  );
}

/// The signed-in user's own reaction on one post, or null if they haven't
/// reacted — cheap (a single doc), safe to watch from every visible card
/// that needs to highlight "your" emoji in the quick-reaction picker.
final myFeedReactionProvider = StreamProvider.autoDispose
    .family<FeedReaction?, FeedReactionTarget>((ref, target) {
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return _repositoryFor(ref, target).watchMine(uid);
});

/// Every reaction on one post, for the "N Reactions" detail sheet only —
/// deliberately not read by the card itself (which uses the post's own
/// denormalized `reactionSummary`/`reactionTotal` for the pill), so this
/// heavier subcollection listener only exists while the sheet is open.
final allFeedReactionsProvider = StreamProvider.autoDispose
    .family<List<FeedReaction>, FeedReactionTarget>((ref, target) {
  return _repositoryFor(ref, target).watchAll();
});
