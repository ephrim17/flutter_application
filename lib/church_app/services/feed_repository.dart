import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class FeedRepository {
  final FirebaseFirestore _firestore;

  FeedRepository(this._firestore);

  Stream<List<FeedPost>> watchFeed(String churchId) {
    return FirestorePaths.feedCollection(_firestore, churchId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return FeedPost.fromJson(
          doc.id,
          doc.data() as Map<String, dynamic>,
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

    /// If new image selected → upload & replace
    if (imageFile != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('churches/$churchId/posts/$postId.jpg');

      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    }

    await FirestorePaths.feedCollection(_firestore, churchId)
        .doc(postId)
        .update({
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
