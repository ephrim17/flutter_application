import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/for_you_section_config_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/home_section_config_model.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
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
      FirestorePaths.churchEvents(firestore, churchId)
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );

  CollectionReference<Map<String, dynamic>> get announcementsRef =>
      FirestorePaths.churchAnnouncements(firestore, churchId)
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );

  CollectionReference<Map<String, dynamic>> get articlesRef =>
      FirestorePaths.churchDailyArticles(firestore, churchId)
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );

  DocumentReference<Map<String, dynamic>> get appConfigRef =>
      FirestorePaths.churchAppConfig(firestore, churchId);
  CollectionReference<Map<String, dynamic>> get notificationRequestsRef =>
      FirestorePaths.churchNotificationRequests(firestore, churchId);
  CollectionReference<HomeSectionConfigModel> get homeSectionsRef =>
      FirestorePaths.churchHomeSections(firestore, churchId)
          .withConverter<HomeSectionConfigModel>(
        fromFirestore: (snapshot, _) =>
            HomeSectionConfigModel.fromFirestore(snapshot),
        toFirestore: (value, _) => value.toMap(),
      );
  CollectionReference<ForYouSectionConfigModel> get forYouSectionsRef =>
      FirestorePaths.churchForYouSections(firestore, churchId)
          .withConverter<ForYouSectionConfigModel>(
        fromFirestore: (snapshot, _) =>
            ForYouSectionConfigModel.fromFirestore(snapshot),
        toFirestore: (value, _) => value.toMap(),
      );

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchEvents() {
    return eventsRef.snapshots().map((snapshot) => snapshot.docs);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      watchAnnouncements() {
    return announcementsRef
        .orderBy('priority')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchArticles() {
    return articlesRef.snapshots().map((snapshot) => snapshot.docs);
  }

  Stream<List<HomeSectionConfigModel>> watchHomeSectionConfigs() {
    return homeSectionsRef
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<ForYouSectionConfigModel>> watchForYouSectionConfigs() {
    return forYouSectionsRef
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
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
    PickedImageData? imageFile,
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
    PickedImageData? imageFile,
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
    required PickedImageData imageFile,
  }) async {
    final storageRef = _storage
        .ref()
        .child('churches/$churchId/announcements/$announcementId.jpg');

    await storageRef.putData(
      imageFile.bytes,
      _metadataFor(imageFile.name),
    );
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

  Future<void> updateHomeSectionConfig({
    required String id,
    required bool enabled,
    required int order,
  }) async {
    await homeSectionsRef.doc(id).set(
          HomeSectionConfigModel(
            id: id,
            enabled: enabled,
            order: order,
          ),
          SetOptions(merge: true),
        );
  }

  Future<void> updateForYouSectionConfig({
    required String id,
    required bool enabled,
    required int order,
  }) async {
    await forYouSectionsRef.doc(id).set(
          ForYouSectionConfigModel(
            id: id,
            enabled: enabled,
            order: order,
          ),
          SetOptions(merge: true),
        );
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

  Future<void> updateAdmins(List<String> admins) async {
    await appConfigRef.set({
      'admins': admins,
    }, SetOptions(merge: true));
  }

  Future<void> updatePromptSheet({
    required String title,
    required String desc,
    required bool enabled,
  }) async {
    await appConfigRef.set({
      'promptSheet': {
        'title': title,
        'desc': desc,
        'enabled': enabled,
      },
    }, SetOptions(merge: true));
  }

  Future<void> queueTopicNotification({
    required String title,
    required String body,
    required String topic,
  }) async {
    await notificationRequestsRef.add({
      'title': title,
      'body': body,
      'topic': topic,
      'status': 'queued',
      'createdAt': FieldValue.serverTimestamp(),
    });
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
