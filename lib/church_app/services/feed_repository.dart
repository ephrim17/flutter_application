import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class FeedRepository {
  final FirebaseFirestore _firestore;
  static const int recentFeedWindowDays = 90;

  FeedRepository(this._firestore);
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const int defaultFeedPageSize = 20;

  Query<Map<String, dynamic>> _feedQuery({
    String? churchId,
    bool isGlobal = false,
    DocumentSnapshot? startAfter,
    int limit = defaultFeedPageSize,
  }) {
    final collection = isGlobal
        ? FirestorePaths.globalFeedCollection(_firestore)
        : FirestorePaths.feedCollection(_firestore, churchId!);
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: recentFeedWindowDays)),
    );

    Query<Map<String, dynamic>> query = collection
        .where('createdAt', isGreaterThanOrEqualTo: cutoff)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query;
  }

  Future<FeedPageResult> fetchFeedPage({
    String? churchId,
    bool isGlobal = false,
    DocumentSnapshot? startAfter,
    int limit = defaultFeedPageSize,
  }) async {
    final snapshot = await _feedQuery(
      churchId: churchId,
      isGlobal: isGlobal,
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
    return _feedQuery(churchId: churchId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return FeedPost.fromJson(
          doc.id,
          doc.data(),
        );
      }).toList();
    });
  }

  Reference _feedImageRef({
    String? churchId,
    required String postId,
    bool isGlobal = false,
  }) {
    if (isGlobal) {
      return _storage.ref().child('churches/global/feeds/$postId.jpg');
    }

    return _storage.ref().child('churches/$churchId/feed/$postId.jpg');
  }

  Future<void> createPost({
    String? churchId,
    required String userId,
    required String userName,
    String? userPhoto,
    String? churchName,
    String? churchPastorName,
    bool sharePersonalDetails = false,
    String? userCategory,
    String? userAddress,
    String? userEmail,
    String? userPhone,
    DateTime? userDob,
    required String title,
    required String description,
    PickedImageData? imageFile,
    bool isGlobal = false,
  }) async {
    final postsRef = isGlobal
        ? FirestorePaths.globalFeedCollection(_firestore)
        : FirestorePaths.feedCollection(_firestore, churchId!);

    // 1️⃣ Create post first (without image)
    final docRef = postsRef.doc();

    await docRef.set({
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'churchId': churchId,
      'churchName': churchName,
      'churchPastorName': churchPastorName,
      'sharePersonalDetails': sharePersonalDetails,
      'userCategory': sharePersonalDetails ? userCategory : null,
      'userAddress': sharePersonalDetails ? userAddress : null,
      'userEmail': sharePersonalDetails ? userEmail : null,
      'userPhone': sharePersonalDetails ? userPhone : null,
      'userDob': sharePersonalDetails && userDob != null
          ? Timestamp.fromDate(userDob)
          : null,
      'title': title,
      'description': description,
      'imageUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2️⃣ Upload image if exists
    if (imageFile != null) {
      final storageRef = _feedImageRef(
        churchId: churchId,
        postId: docRef.id,
        isGlobal: isGlobal,
      );

      await storageRef.putData(
        imageFile.bytes,
        _metadataFor(imageFile.name),
      );

      final downloadUrl = await storageRef.getDownloadURL();

      // 3️⃣ Update document with image URL
      await docRef.update({
        'imageUrl': downloadUrl,
      });
    }

    if (!isGlobal && churchId != null && churchId.isNotEmpty) {
      await FirestorePaths.churchNotificationRequests(_firestore, churchId).add({
        'title': '$userName has posted a new feed',
        'body': 'Tap to see more',
        'topic': 'church_$churchId',
        'status': 'queued',
        'kind': 'feed_post_created',
        'feedId': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updatePost({
    String? churchId,
    required String postId,
    required String title,
    required String description,
    PickedImageData? imageFile,
    String? existingImageUrl,
    bool? sharePersonalDetails,
    String? userCategory,
    String? userAddress,
    String? userEmail,
    String? userPhone,
    DateTime? userDob,
    bool isGlobal = false,
  }) async {
    String? imageUrl = existingImageUrl;

    if (imageFile != null) {
      final storageRef = _feedImageRef(
        churchId: churchId,
        postId: postId,
        isGlobal: isGlobal,
      );

      await storageRef.putData(
        imageFile.bytes,
        _metadataFor(imageFile.name),
      );
      imageUrl = await storageRef.getDownloadURL();
    }

    final docRef = isGlobal
        ? FirestorePaths.globalFeedCollection(_firestore).doc(postId)
        : FirestorePaths.feedCollection(_firestore, churchId!).doc(postId);

    await docRef.update({
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      if (sharePersonalDetails != null)
        'sharePersonalDetails': sharePersonalDetails,
      if (sharePersonalDetails != null)
        'userCategory': sharePersonalDetails ? userCategory : null,
      if (sharePersonalDetails != null)
        'userAddress': sharePersonalDetails ? userAddress : null,
      if (sharePersonalDetails != null)
        'userEmail': sharePersonalDetails ? userEmail : null,
      if (sharePersonalDetails != null)
        'userPhone': sharePersonalDetails ? userPhone : null,
      if (sharePersonalDetails != null)
        'userDob': sharePersonalDetails && userDob != null
            ? Timestamp.fromDate(userDob)
            : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePost({
    String? churchId,
    required String postId,
    String? imageUrl,
    bool isGlobal = false,
  }) async {
    try {
      await _feedImageRef(
        churchId: churchId,
        postId: postId,
        isGlobal: isGlobal,
      ).delete();
    } on FirebaseException catch (e) {
      // Fall back to the saved URL for older posts or mismatched legacy paths.
      if (e.code != 'object-not-found') {
        rethrow;
      }

      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(imageUrl).delete();
        } on FirebaseException catch (fallbackError) {
          if (fallbackError.code != 'object-not-found') {
            rethrow;
          }
        }
      }
    }

    // Always delete the feed document (text/title/description).
    final docRef = isGlobal
        ? FirestorePaths.globalFeedCollection(_firestore).doc(postId)
        : FirestorePaths.feedCollection(_firestore, churchId!).doc(postId);

    await docRef.delete();
  }
}

SettableMetadata _metadataFor(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return SettableMetadata(contentType: 'image/png');
  if (lower.endsWith('.webp')) {
    return SettableMetadata(contentType: 'image/webp');
  }
  if (lower.endsWith('.gif')) return SettableMetadata(contentType: 'image/gif');
  return SettableMetadata(contentType: 'image/jpeg');
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
