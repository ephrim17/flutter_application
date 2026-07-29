import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';

void main() {
  group('FeedPost edit window', () {
    final createdAt = DateTime.utc(2026, 7, 28, 12);
    final post = FeedPost(
      id: 'post-id',
      userId: 'user-id',
      userName: 'User',
      title: 'Title',
      description: 'Description',
      createdAt: createdAt,
      likeCount: 0,
      commentCount: 0,
    );

    test('allows editing through the first 30 minutes', () {
      expect(post.canEditAt(createdAt), isTrue);
      expect(
        post.canEditAt(createdAt.add(const Duration(minutes: 30))),
        isTrue,
      );
    });

    test('prevents editing after 30 minutes', () {
      expect(
        post.canEditAt(
          createdAt.add(const Duration(minutes: 30, microseconds: 1)),
        ),
        isFalse,
      );
    });

    test('reads linked global-post metadata', () {
      final promotedPost = FeedPost.fromJson('church_post', {
        'userId': 'user-id',
        'userName': 'User',
        'title': 'Title',
        'description': 'Description',
        'createdAt': Timestamp.fromDate(createdAt),
        'isGlobal': true,
        'sourceChurchId': 'church-id',
        'sourcePostId': 'post-id',
      });

      expect(promotedPost.isGlobal, isTrue);
      expect(promotedPost.sourceChurchId, 'church-id');
      expect(promotedPost.sourcePostId, 'post-id');
    });

    test('creates an optimistic promoted copy without losing post content', () {
      final promotedPost = post.copyWith(
        id: 'church-id_post-id',
        isGlobal: true,
        sourceChurchId: 'church-id',
        sourcePostId: post.id,
        isPinned: false,
        clearPinnedAt: true,
      );

      expect(promotedPost.id, 'church-id_post-id');
      expect(promotedPost.isGlobal, isTrue);
      expect(promotedPost.sourceChurchId, 'church-id');
      expect(promotedPost.sourcePostId, post.id);
      expect(promotedPost.title, post.title);
      expect(promotedPost.description, post.description);
    });
  });
}
