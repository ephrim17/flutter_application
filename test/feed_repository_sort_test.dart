import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/services/feed_repository.dart';

FeedPost _post(
  String id, {
  required DateTime createdAt,
  bool isPinned = false,
  DateTime? pinnedAt,
}) {
  return FeedPost(
    id: id,
    userId: 'user-id',
    userName: 'User',
    title: 'Title $id',
    description: 'Description',
    createdAt: createdAt,
    isPinned: isPinned,
    pinnedAt: pinnedAt,
    likeCount: 0,
    commentCount: 0,
  );
}

void main() {
  group('sortFeedPosts', () {
    test('places a freshly created post right after the pinned post', () {
      final pinned = _post(
        'pinned',
        createdAt: DateTime.utc(2026, 8, 15),
        isPinned: true,
        pinnedAt: DateTime.utc(2026, 8, 15),
      );
      final older = _post('older', createdAt: DateTime.utc(2026, 9, 1));
      final justCreated =
          _post('new', createdAt: DateTime.utc(2026, 9, 5, 23, 30));

      // Mirrors FeedPaginationController.insertLocalPost: the new post is
      // prepended to whatever is already loaded, then re-sorted.
      final sorted = sortFeedPosts([justCreated, pinned, older]);

      expect(sorted.map((post) => post.id), ['pinned', 'new', 'older']);
    });

    test('does not duplicate a post that is inserted twice by id', () {
      final createdAt = DateTime.utc(2026, 9, 5, 23, 30);
      final post = _post('new', createdAt: createdAt);
      final existing = [_post('older', createdAt: DateTime.utc(2026, 9, 1))];

      final merged = sortFeedPosts([
        post,
        ...existing.where((p) => p.id != post.id),
      ]);

      expect(merged.length, 2);
      expect(merged.first.id, 'new');
    });
  });
}
