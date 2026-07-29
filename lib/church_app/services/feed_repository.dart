import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class FeedRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  static const int recentFeedWindowDays = 90;

  FeedRepository(this._firestore, [FirebaseFunctions? functions])
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const int defaultFeedPageSize = 20;

  String _globalPostId(String churchId, String postId) => '${churchId}_$postId';

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
    final pinnedPost = startAfter == null
        ? await fetchPinnedPost(churchId: churchId, isGlobal: isGlobal)
        : null;
    final snapshot = await _feedQuery(
      churchId: churchId,
      isGlobal: isGlobal,
      startAfter: startAfter,
      limit: limit,
    ).get();

    final posts = snapshot.docs
        .map((doc) => FeedPost.fromJson(doc.id, doc.data()))
        .where((post) => post.id != pinnedPost?.id)
        .toList();
    if (pinnedPost != null) {
      posts.insert(0, pinnedPost);
    }

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

  Future<FeedPost?> fetchPinnedPost({
    String? churchId,
    bool isGlobal = false,
  }) async {
    final collection = isGlobal
        ? FirestorePaths.globalFeedCollection(_firestore)
        : FirestorePaths.feedCollection(_firestore, churchId!);

    final snapshot = await collection
        .where('isPinned', isEqualTo: true)
        .limit(10)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        )
        .get();

    final posts = snapshot.docs
        .map((doc) => FeedPost.fromJson(doc.id, doc.data()))
        .toList(growable: false);
    final sortedPosts = sortFeedPosts(posts);
    return sortedPosts.isEmpty ? null : sortedPosts.first;
  }

  Future<List<FeedPost>> fetchPostsByHashtag({
    required String hashtag,
    String? churchId,
    bool isGlobal = false,
    int limit = 100,
  }) async {
    final normalizedHashtag = normalizeHashtag(hashtag);
    if (normalizedHashtag.isEmpty) return const [];

    final collection = isGlobal
        ? FirestorePaths.globalFeedCollection(_firestore)
        : FirestorePaths.feedCollection(_firestore, churchId!);

    final snapshot = await collection
        .where('hashtags', arrayContains: normalizedHashtag)
        .limit(limit)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        )
        .get();

    final posts = snapshot.docs
        .map((doc) => FeedPost.fromJson(doc.id, doc.data()))
        .toList(growable: false);

    if (posts.isNotEmpty) {
      return sortFeedPosts(posts);
    }

    return _fetchPostsByHashtagFromRecentText(
      hashtag: normalizedHashtag,
      churchId: churchId,
      isGlobal: isGlobal,
      limit: limit,
    );
  }

  Future<List<FeedPost>> _fetchPostsByHashtagFromRecentText({
    required String hashtag,
    String? churchId,
    required bool isGlobal,
    required int limit,
  }) async {
    final snapshot = await _feedQuery(
      churchId: churchId,
      isGlobal: isGlobal,
      limit: limit,
    ).get();

    final posts = snapshot.docs
        .map((doc) => FeedPost.fromJson(doc.id, doc.data()))
        .where(
          (post) => extractHashtags('${post.title}\n${post.description}')
              .contains(hashtag),
        )
        .toList(growable: false);

    return sortFeedPosts(posts);
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

  Reference _feedGalleryImageRef({
    String? churchId,
    required String postId,
    required int index,
    required String fileName,
    bool isGlobal = false,
  }) {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final scope = isGlobal ? 'global' : churchId;
    return _storage
        .ref()
        .child('churches/$scope/feeds/$postId/images/$index-$safeName');
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
    List<PickedImageData> imageFiles = const [],
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
      'hashtags': extractHashtags('$title\n$description'),
      'isGlobal': isGlobal,
      'sourceChurchId': '',
      'sourcePostId': '',
      'isPinned': false,
      'pinnedAt': null,
      'imageUrl': null,
      'imageUrls': const <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2️⃣ Upload image if exists
    if (imageFiles.isNotEmpty) {
      final downloadUrls = <String>[];
      for (var index = 0; index < imageFiles.length; index++) {
        final imageFile = imageFiles[index];
        final storageRef = _feedGalleryImageRef(
          churchId: churchId,
          postId: docRef.id,
          index: index,
          fileName: imageFile.name,
          isGlobal: isGlobal,
        );
        await storageRef.putData(
          imageFile.bytes,
          _metadataFor(imageFile.name),
        );
        downloadUrls.add(await storageRef.getDownloadURL());
      }
      await docRef.update({
        'imageUrl': downloadUrls.first,
        'imageUrls': downloadUrls,
      });
    }

    if (!isGlobal && churchId != null && churchId.isNotEmpty) {
      await FirestorePaths.churchNotificationRequests(_firestore, churchId)
          .add({
        'title': '$userName has posted a new feed',
        'body': 'Tap to see more',
        'topic': 'church_$churchId',
        'status': 'queued',
        'kind': 'feed_post_created',
        'feedId': docRef.id,
        'authorId': userId,
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

    final updates = <String, dynamic>{
      'title': title,
      'description': description,
      'hashtags': extractHashtags('$title\n$description'),
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
    };

    final existingSnapshot = !isGlobal ? await docRef.get() : null;
    final existingData = existingSnapshot?.data() as Map<String, dynamic>?;
    final batch = _firestore.batch()..update(docRef, updates);
    if (existingData?['isGlobal'] == true) {
      batch.set(
        FirestorePaths.globalFeedCollection(_firestore)
            .doc(_globalPostId(churchId!, postId)),
        updates,
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> deletePost({
    String? churchId,
    required String postId,
    String? imageUrl,
    List<String> imageUrls = const [],
    bool isGlobal = false,
  }) async {
    final docRef = isGlobal
        ? FirestorePaths.globalFeedCollection(_firestore).doc(postId)
        : FirestorePaths.feedCollection(_firestore, churchId!).doc(postId);

    if (isGlobal) {
      final snapshot = await docRef.get();
      final data = snapshot.data() as Map<String, dynamic>?;
      final sourceChurchId = (data?['sourceChurchId'] ?? '').toString().trim();
      final sourcePostId = (data?['sourcePostId'] ?? '').toString().trim();
      if (sourceChurchId.isNotEmpty && sourcePostId.isNotEmpty) {
        final sourceRef = FirestorePaths.feedCollection(
          _firestore,
          sourceChurchId,
        ).doc(sourcePostId);
        final batch = _firestore.batch()..delete(docRef);
        final sourceSnapshot = await sourceRef.get();
        if (sourceSnapshot.exists) {
          batch.update(sourceRef, {
            'isGlobal': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        return;
      }
    }

    final urlsToDelete = {
      ...imageUrls.where((url) => url.trim().isNotEmpty),
      if (imageUrl != null && imageUrl.trim().isNotEmpty) imageUrl,
    };
    for (final url in urlsToDelete) {
      try {
        await _storage.refFromURL(url).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }

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

      if (urlsToDelete.isEmpty && imageUrl != null && imageUrl.isNotEmpty) {
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
    final batch = _firestore.batch()..delete(docRef);
    if (!isGlobal) {
      batch.delete(
        FirestorePaths.globalFeedCollection(_firestore)
            .doc(_globalPostId(churchId!, postId)),
      );
    }
    await batch.commit();
  }

  Future<void> setPostGlobal({
    required String churchId,
    required String postId,
    required bool isGlobal,
  }) async {
    final callable = _functions.httpsCallable('setFeedPostGlobal');
    await callable.call<void>({
      'churchId': churchId,
      'postId': postId,
      'isGlobal': isGlobal,
    });
  }

  Future<void> setPinnedPost({
    String? churchId,
    required String postId,
    required bool pinned,
    bool isGlobal = false,
  }) async {
    final collection = isGlobal
        ? FirestorePaths.globalFeedCollection(_firestore)
        : FirestorePaths.feedCollection(_firestore, churchId!);
    final postRef = collection.doc(postId);

    final batch = _firestore.batch();

    if (pinned) {
      final currentPinnedSnapshot =
          await collection.where('isPinned', isEqualTo: true).limit(10).get();

      for (final doc in currentPinnedSnapshot.docs) {
        if (doc.id == postId) continue;
        batch.update(doc.reference, {
          'isPinned': false,
          'pinnedAt': null,
        });
      }
    }

    batch.update(postRef, {
      'isPinned': pinned,
      'pinnedAt': pinned ? FieldValue.serverTimestamp() : null,
    });
    await batch.commit();
  }
}

List<FeedPost> sortFeedPosts(Iterable<FeedPost> posts) {
  final sorted = posts.toList(growable: false);
  sorted.sort((a, b) {
    if (a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1;
    }

    final aPinnedAt = a.pinnedAt;
    final bPinnedAt = b.pinnedAt;
    if (aPinnedAt != null && bPinnedAt != null) {
      return bPinnedAt.compareTo(aPinnedAt);
    }

    return b.createdAt.compareTo(a.createdAt);
  });
  return sorted;
}

List<String> extractHashtags(String text) {
  return _hashtagPattern
      .allMatches(text)
      .map((match) => normalizeHashtag(match.group(1) ?? ''))
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

String normalizeHashtag(String value) {
  return value
      .trim()
      .replaceFirst(RegExp(r'^#+'), '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}_]+', unicode: true), '');
}

final RegExp _hashtagPattern = RegExp(
  r'(?:^|\s)#([\p{L}\p{M}\p{N}_]+)',
  unicode: true,
);

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
