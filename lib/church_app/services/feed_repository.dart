import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class FeedRepository {
  final FirebaseFirestore _firestore;

  FeedRepository(this._firestore);
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const int defaultFeedPageSize = 20;

  Query<Map<String, dynamic>> _feedQuery({
    required String churchId,
    DocumentSnapshot? startAfter,
    int limit = defaultFeedPageSize,
  }) {
    Query<Map<String, dynamic>> query = FirestorePaths
        .feedCollection(_firestore, churchId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query;
  }

  Future<FeedPageResult> fetchFeedPage({
    required String churchId,
    DocumentSnapshot? startAfter,
    int limit = defaultFeedPageSize,
  }) async {
    final snapshot = await _feedQuery(
      churchId: churchId,
      startAfter: startAfter,
      limit: limit,
    ).get();

    final posts = snapshot.docs
        .map((doc) => FeedPost.fromJson(doc.id, doc.data()))
        .toList();

    return FeedPageResult(
      posts: posts,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Stream<List<FeedPost>> watchFeed(String churchId) {
    return _feedQuery(churchId: churchId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return FeedPost.fromJson(
          doc.id,
          doc.data(),
        );
      }).toList();
    });
  }

  Future<void> createPost({
    required String churchId,
    required String userId,
    required String userName,
    required String title,
    required String description,
    File? imageFile,
  }) async {
    final postsRef = FirestorePaths.feedCollection(_firestore, churchId);

    // 1️⃣ Create post first (without image)
    final docRef = postsRef.doc();

    await docRef.set({
      'userId': userId,
      'userName': userName,
      'title': title,
      'description': description,
      'imageUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2️⃣ Upload image if exists
    if (imageFile != null) {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('churches/$churchId/feed/${docRef.id}.jpg');

      print("<<< storageRef >>>");
      print(storageRef);

      await storageRef.putFile(imageFile);

      final downloadUrl = await storageRef.getDownloadURL();

      // 3️⃣ Update document with image URL
      await docRef.update({
        'imageUrl': downloadUrl,
      });
    }
  }

  Future<void> updatePost({
    required String churchId,
    required String postId,
    required String title,
    required String description,
    File? imageFile,
    String? existingImageUrl,
  }) async {
    String? imageUrl = existingImageUrl;

    if (imageFile != null) {
      final storageRef = _storage
          .ref()
          .child('churches/$churchId/posts/$postId.jpg');

      await storageRef.putFile(imageFile);
      imageUrl = await storageRef.getDownloadURL();
    }

    await FirestorePaths
        .feedCollection(_firestore, churchId)
        .doc(postId)
        .update({
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePost({
    required String churchId,
    required String postId,
    String? imageUrl,
  }) async {
    // Delete storage object only when this post has an image.
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(imageUrl).delete();
      } on FirebaseException catch (e) {
        // Don't block post deletion if image is already missing.
        if (e.code != 'object-not-found') {
          rethrow;
        }
      }
    }

    // Always delete the feed document (text/title/description).
    await FirestorePaths.feedCollection(_firestore, churchId).doc(postId).delete();
  }
}

class FeedPageResult {
  final List<FeedPost> posts;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const FeedPageResult({
    required this.posts,
    required this.lastDocument,
    required this.hasMore,
  });
}
