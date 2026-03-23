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
  DocumentReference<Map<String, dynamic>> get aboutRef =>
      FirestorePaths.churchAboutDoc(firestore, churchId);
  DocumentReference<Map<String, dynamic>> get bibleSwipeRef =>
      FirestorePaths.churchBibleRandomSwipeDoc(firestore, churchId);
  CollectionReference<Map<String, dynamic>> get notificationRequestsRef =>
      FirestorePaths.churchNotificationRequests(firestore, churchId);
  CollectionReference<Map<String, dynamic>> get pastorsRef =>
      FirestorePaths.churchPastors(firestore, churchId)
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );
  CollectionReference<Map<String, dynamic>> get contactItemsRef =>
      FirestorePaths.churchContactItems(firestore, churchId)
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );
  CollectionReference<Map<String, dynamic>> get socialItemsRef =>
      FirestorePaths.churchSocialItems(firestore, churchId)
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      );
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

  Stream<Map<String, dynamic>?> watchAbout() {
    return aboutRef.snapshots().map((snapshot) => snapshot.data());
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchPastors() {
    return pastorsRef.snapshots().map((snapshot) => snapshot.docs);
  }

  Stream<List<String>> watchBibleSwipeVerses() {
    return bibleSwipeRef.snapshots().map((snapshot) {
      final data = snapshot.data();
      final verses = data?['verses'] as List<dynamic>? ?? const [];
      return verses
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      watchContactItems() {
    return contactItemsRef.orderBy('order').snapshots().map((snapshot) {
      return snapshot.docs;
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchSocialItems() {
    return socialItemsRef.orderBy('order').snapshots().map((snapshot) {
      return snapshot.docs;
    });
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

  Future<void> updateAbout({
    required String title,
    required String tagline,
    required String description,
    required String mission,
    required String community,
    required String values,
  }) async {
    await aboutRef.set({
      'title': title,
      'tagline': tagline,
      'description': description,
      'mission': mission,
      'community': community,
      'values': values,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> createPastor(Map<String, dynamic> data) async {
    await pastorsRef.add(data);
  }

  Future<void> updatePastor(String id, Map<String, dynamic> data) async {
    await pastorsRef.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> deletePastor(String id) async {
    await pastorsRef.doc(id).delete();
  }

  Future<void> updateBibleSwipeVerses(List<String> verses) async {
    await bibleSwipeRef.set({
      'verses': verses,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> createContactItem(Map<String, dynamic> data) async {
    await contactItemsRef.add(data);
  }

  Future<void> updateContactItem(String id, Map<String, dynamic> data) async {
    await contactItemsRef.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteContactItem(String id) async {
    await contactItemsRef.doc(id).delete();
  }

  Future<void> createSocialItem(Map<String, dynamic> data) async {
    await socialItemsRef.add(data);
  }

  Future<void> updateSocialItem(String id, Map<String, dynamic> data) async {
    await socialItemsRef.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteSocialItem(String id) async {
    await socialItemsRef.doc(id).delete();
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

  Future<void> updateThemeColors({
    required String primaryColor,
    required String secondaryColor,
  }) async {
    await appConfigRef.set({
      'theme': {
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
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
