import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class StudioRepository {
  StudioRepository({
    required this.firestore,
    required this.churchId,
  });

  final FirebaseFirestore firestore;
  final String churchId;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get eventsRef =>
      FirestorePaths.churchEvents(firestore, churchId).withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );

  CollectionReference<Map<String, dynamic>> get announcementsRef => FirestorePaths
      .churchAnnouncements(firestore, churchId)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );

  CollectionReference<Map<String, dynamic>> get articlesRef => FirestorePaths
      .churchDailyArticles(firestore, churchId)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );

  DocumentReference<Map<String, dynamic>> get appConfigRef =>
      FirestorePaths.churchAppConfig(firestore, churchId);

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchEvents() {
    return eventsRef.snapshots().map((snapshot) => snapshot.docs);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchAnnouncements() {
    return announcementsRef
        .orderBy('priority')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchArticles() {
    return articlesRef.snapshots().map((snapshot) => snapshot.docs);
  }

  Future<void> createEvent(Map<String, dynamic> data) async {
    await eventsRef.add(data);
  }

  Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    await eventsRef.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteEvent(String id) async {
    await eventsRef.doc(id).delete();
  }

  Future<void> createAnnouncement({
    required Map<String, dynamic> data,
    File? imageFile,
  }) async {
    final docRef = announcementsRef.doc();

    await docRef.set({
      ...data,
      'imageUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (imageFile != null) {
      final downloadUrl = await _uploadAnnouncementImage(
        announcementId: docRef.id,
        imageFile: imageFile,
      );

      await docRef.update({
        'imageUrl': downloadUrl,
      });
    }
  }

  Future<void> updateAnnouncement({
    required String id,
    required Map<String, dynamic> data,
    File? imageFile,
    String? existingImageUrl,
  }) async {
    var imageUrl = existingImageUrl ?? '';

    if (imageFile != null) {
      imageUrl = await _uploadAnnouncementImage(
        announcementId: id,
        imageFile: imageFile,
      );
    }

    await announcementsRef.doc(id).update({
      ...data,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAnnouncement(String id, {String? imageUrl}) async {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(imageUrl).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') {
          rethrow;
        }
      }
    }

    await announcementsRef.doc(id).delete();
  }

  Future<String> _uploadAnnouncementImage({
    required String announcementId,
    required File imageFile,
  }) async {
    final storageRef = _storage
        .ref()
        .child('churches/$churchId/announcements/$announcementId.jpg');

    await storageRef.putFile(imageFile);
    return storageRef.getDownloadURL();
  }

  Future<void> createArticle(Map<String, dynamic> data) async {
    await articlesRef.add(data);
  }

  Future<void> updateArticle(String id, Map<String, dynamic> data) async {
    await articlesRef.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteArticle(String id) async {
    await articlesRef.doc(id).delete();
  }

  Future<void> updateDailyVerse({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    await appConfigRef.set({
      'dailyVerse': {
        'book': book,
        'chapter': chapter,
        'verse': verse,
      },
    }, SetOptions(merge: true));
  }

  Future<void> updatePromiseWord({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    await appConfigRef.set({
      'promiseWord': {
        'book': book,
        'chapter': chapter,
        'verse': verse,
      },
    }, SetOptions(merge: true));
  }
}
