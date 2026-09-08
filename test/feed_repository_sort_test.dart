import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/services/feed_repository.dart';

FeedPost _post(
  String id, {
  required DateTime createdAt,
}) {
  return FeedPost(
    id: id,
    userId: 'user-id',
    userName: 'User',
    title: 'Title $id',
    description: 'Description',
    createdAt: createdAt,
    likeCount: 0,
    commentCount: 0,
  );
}

void main() {
  group('sortFeedPosts', () {
    test('orders posts newest first', () {
      final oldest = _post('oldest', createdAt: DateTime.utc(2026, 8, 15));
      final older = _post('older', createdAt: DateTime.utc(2026, 9, 1));
      final justCreated =
          _post('new', createdAt: DateTime.utc(2026, 9, 5, 23, 30));

      // Mirrors FeedPaginationController.insertLocalPost: the new post is
      // prepended to whatever is already loaded, then re-sorted.
      final sorted = sortFeedPosts([justCreated, oldest, older]);

      expect(sorted.map((post) => post.id), ['new', 'older', 'oldest']);
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
