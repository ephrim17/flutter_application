import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_application/church_app/helpers/church_group_definitions.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class CreateChurchInput {
  const CreateChurchInput({
    required this.churchId,
    required this.name,
    required this.pastorName,
    required this.pastorPhotoImage,
    required this.address,
    required this.contact,
    required this.email,
    required this.logoImage,
    required this.enabled,
    required this.setupChurchAccount,
    this.adminUid,
    this.adminName,
    this.adminEmail,
    this.adminPhone,
  });

  final String churchId;
  final String name;
  final String pastorName;
  final PickedImageData pastorPhotoImage;
  final String address;
  final String contact;
  final String email;
  final PickedImageData logoImage;
  final bool enabled;
  final bool setupChurchAccount;
  final String? adminUid;
  final String? adminName;
  final String? adminEmail;
  final String? adminPhone;
}

class UpdateChurchInput {
  const UpdateChurchInput({
    required this.churchId,
    required this.name,
    required this.pastorName,
    required this.address,
    required this.contact,
    required this.email,
    required this.enabled,
    required this.existingLogoUrl,
    required this.existingPastorPhotoUrl,
    this.logoImage,
    this.pastorPhotoImage,
  });

  final String churchId;
  final String name;
  final String pastorName;
  final String address;
  final String contact;
  final String email;
  final bool enabled;
  final String existingLogoUrl;
  final String existingPastorPhotoUrl;
  final PickedImageData? logoImage;
  final PickedImageData? pastorPhotoImage;
}

class SuperAdminChurchService {
  SuperAdminChurchService(
    this._firestore, {
    FirebaseStorage? storage,
  }) : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const List<String> _homeSectionIds = <String>[
    'announcements',
    'events',
    'footer',
    'promise',
  ];

  static const List<String> _forYouSectionIds = <String>[
    'dailyVerse',
    'featured',
    'footer',
    'article',
  ];

  static const List<String> _defaultSwipeVerses = <String>[
    'Psalms 23:1',
    'John 3:16',
    'Romans 8:28',
  ];

  Future<bool> churchExists(String churchId) async {
    final doc =
        await FirestorePaths.churchDoc(_firestore, churchId.trim()).get();
    return doc.exists;
  }

  Future<void> createChurch(CreateChurchInput input) async {
    final churchId = input.churchId.trim();
    final churchDoc = FirestorePaths.churchDoc(_firestore, churchId);
    if (await churchExists(churchId)) {
      throw const CreateChurchException('duplicate-id');
    }

    final logoUrl = await _uploadChurchLogo(
      churchId: churchId,
      imageFile: input.logoImage,
    );
    final pastorPhotoUrl = await _uploadPastorPhoto(
      churchId: churchId,
      imageFile: input.pastorPhotoImage,
    );

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    final normalizedChurchEmail = input.email.trim().toLowerCase();
    final normalizedAdminEmail = input.adminEmail?.trim().toLowerCase() ?? '';
    final adminGroupIds = <String>['administration'];

    batch.set(churchDoc, {
      'name': input.name.trim(),
      'pastorName': input.pastorName.trim(),
      'pastorPhoto': pastorPhotoUrl,
      'address': input.address.trim(),
      'contact': input.contact.trim(),
      'email': normalizedChurchEmail,
      'logo': logoUrl,
      'enabled': input.enabled,
      'createdAt': now,
      'updatedAt': now,
    });

    final adminEmails = normalizedAdminEmail.isEmpty
        ? <String>[]
        : <String>[normalizedAdminEmail];

    batch.set(
      FirestorePaths.churchAppConfig(_firestore, churchId),
      {
        'admins': adminEmails,
        'features': {
          'membersEnabled': true,
          'eventsEnabled': true,
          'bibleSwipeFetchEnabled': true,
          'bibleSwipeVersion': 1,
        },
        'dailyVerse': {
          'book': 'John',
          'chapter': 3,
          'verse': 16,
        },
        'promiseWord': {
          'book': 'Jeremiah',
          'chapter': 29,
          'verse': 11,
        },
        'promptSheet': {
          'title': '',
          'desc': '',
          'enabled': false,
        },
        'adminMode': {
          'enabled': false,
        },
        'onboarding': {
          'title': '',
          'subtitle': '',
        },
        'theme': {
          'primaryColor': '#000000',
          'secondaryColor': '#000000',
          'backgroundColor': '#FFFFFF',
          'cardBackgroundColor': '#FFFFFF',
        },
        'textContent': <String, String>{
          'church_tab.app_title': input.name.trim(),
        },
        'churchLogo': logoUrl,
        'youtubeLink': '',
      },
    );

    batch.set(
      FirestorePaths.churchAboutDoc(_firestore, churchId),
      {
        'title': input.name.trim(),
        'tagline': '',
        'description': '',
        'mission': '',
        'community': '',
        'values': '',
      },
    );

    batch.set(
      FirestorePaths.churchBibleRandomSwipeDoc(_firestore, churchId),
      {
        'verses': _defaultSwipeVerses,
      },
    );

    batch.set(
      _firestore
          .collection(FirestorePaths.churches)
          .doc(churchId)
          .collection(FirestorePaths.footerSupport)
          .doc(FirestorePaths.contactsDoc),
      {
        'initializedAt': now,
      },
    );

    batch.set(
      _firestore
          .collection(FirestorePaths.churches)
          .doc(churchId)
          .collection(FirestorePaths.footerSupport)
          .doc(FirestorePaths.socialDoc),
      {
        'initializedAt': now,
      },
    );

    _seedFooterContacts(
      batch: batch,
      churchId: churchId,
      email: normalizedChurchEmail,
      contact: input.contact.trim(),
      address: input.address.trim(),
      now: now,
    );

    if (input.pastorName.trim().isNotEmpty || input.contact.trim().isNotEmpty) {
      batch.set(
        FirestorePaths.churchPastors(_firestore, churchId).doc('primary'),
        {
          'title': input.pastorName.trim(),
          'contact': input.contact.trim(),
          'imageUrl': pastorPhotoUrl,
          'updatedAt': now,
        },
      );
    }

    if (input.setupChurchAccount &&
        input.adminUid != null &&
        input.adminName != null &&
        input.adminEmail != null &&
        input.adminPhone != null) {
      batch.set(
        FirestorePaths.churchUserDoc(
          _firestore,
          churchId,
          input.adminUid!.trim(),
        ),
        {
          'uid': input.adminUid!.trim(),
          'name': input.adminName!.trim(),
          'email': normalizedAdminEmail,
          'phone': input.adminPhone!.trim(),
          'contact': input.adminPhone!.trim(),
          'location': '',
          'address': input.address.trim(),
          'gender': '',
          'category': 'individual',
          'familyId': '',
          'maritalStatus': '',
          'weddingDay': null,
          'financialStabilityRating': 0,
          'financialSupportRequired': false,
          'educationalQualification': '',
          'talentsAndGifts': const <String>[],
          'churchGroupIds': adminGroupIds,
          'role': 'admin',
          'authToken': '',
          'approved': true,
          'dob': null,
          'createdAt': now,
        },
      );
    }

    if (input.adminName != null &&
        input.adminEmail != null &&
        input.adminPhone != null &&
        input.adminName!.trim().isNotEmpty &&
        normalizedAdminEmail.isNotEmpty) {
      final adminMemberId = input.setupChurchAccount &&
              input.adminUid != null &&
              input.adminUid!.trim().isNotEmpty
          ? input.adminUid!.trim()
          : normalizedAdminEmail;

      batch.set(
        FirestorePaths.churchGroupMembers(
          _firestore,
          churchId,
          'administration',
        ).doc(adminMemberId),
        {
          'uid': adminMemberId,
          'email': normalizedAdminEmail,
          'name': input.adminName!.trim(),
          'phone': input.adminPhone!.trim(),
          'category': 'individual',
          'groupId': 'administration',
          'groupLabel': 'Administration',
          'updatedAt': now,
        },
      );
    }

    _seedChurchGroups(
      batch: batch,
      churchId: churchId,
      now: now,
    );

    for (var i = 0; i < _homeSectionIds.length; i++) {
      batch.set(
        FirestorePaths.churchHomeSections(_firestore, churchId)
            .doc(_homeSectionIds[i]),
        {
          'enabled': false,
          'order': i + 1,
        },
      );
    }

    for (var i = 0; i < _forYouSectionIds.length; i++) {
      batch.set(
        FirestorePaths.churchForYouSections(_firestore, churchId)
            .doc(_forYouSectionIds[i]),
        {
          'enabled': false,
          'order': i + 1,
        },
      );
    }

    await batch.commit();
  }

  Future<void> updateChurch(UpdateChurchInput input) async {
    final churchId = input.churchId.trim();
    final churchDoc = FirestorePaths.churchDoc(_firestore, churchId);
    final now = FieldValue.serverTimestamp();
    final normalizedChurchEmail = input.email.trim().toLowerCase();

    final logoUrl = input.logoImage != null
        ? await _uploadChurchLogo(
            churchId: churchId,
            imageFile: input.logoImage!,
          )
        : input.existingLogoUrl.trim();

    final pastorPhotoUrl = input.pastorPhotoImage != null
        ? await _uploadPastorPhoto(
            churchId: churchId,
            imageFile: input.pastorPhotoImage!,
          )
        : input.existingPastorPhotoUrl.trim();

    final batch = _firestore.batch();

    batch.set(
      churchDoc,
      {
        'name': input.name.trim(),
        'pastorName': input.pastorName.trim(),
        'pastorPhoto': pastorPhotoUrl,
        'address': input.address.trim(),
        'contact': input.contact.trim(),
        'email': normalizedChurchEmail,
        'logo': logoUrl,
        'enabled': input.enabled,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    batch.set(
      FirestorePaths.churchAppConfig(_firestore, churchId),
      {
        'textContent': <String, String>{
          'church_tab.app_title': input.name.trim(),
        },
        'churchLogo': logoUrl,
      },
      SetOptions(merge: true),
    );

    batch.set(
      FirestorePaths.churchAboutDoc(_firestore, churchId),
      {
        'title': input.name.trim(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      FirestorePaths.churchPastors(_firestore, churchId).doc('primary'),
      {
        'title': input.pastorName.trim(),
        'contact': input.contact.trim(),
        'imageUrl': pastorPhotoUrl,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<String> _uploadChurchLogo({
    required String churchId,
    required PickedImageData imageFile,
  }) async {
    final storageRef = _storage.ref().child('churches/$churchId/logo');
    await storageRef.putData(
      imageFile.bytes,
      _metadataFor(imageFile.name),
    );
    return storageRef.getDownloadURL();
  }

  Future<String> _uploadPastorPhoto({
    required String churchId,
    required PickedImageData imageFile,
  }) async {
    final storageRef = _storage.ref().child('churches/$churchId/pastor_photo');
    await storageRef.putData(
      imageFile.bytes,
      _metadataFor(imageFile.name),
    );
    return storageRef.getDownloadURL();
  }

  void _seedFooterContacts({
    required WriteBatch batch,
    required String churchId,
    required String email,
    required String contact,
    required String address,
    required Object now,
  }) {
    final items = <({String id, Map<String, dynamic> data})>[];

    if (contact.isNotEmpty) {
      items.add((
        id: 'phone',
        data: {
          'label': 'Phone',
          'type': 'phone',
          'action': 'tel:$contact',
          'order': 1,
          'isActive': true,
          'updatedAt': now,
        }
      ));
    }

    if (email.isNotEmpty) {
      items.add((
        id: 'email',
        data: {
          'label': 'Email',
          'type': 'email',
          'action': 'mailto:$email',
          'order': items.length + 1,
          'isActive': true,
          'updatedAt': now,
        }
      ));
    }

    if (address.isNotEmpty) {
      items.add((
        id: 'location',
        data: {
          'label': 'Location',
          'type': 'location',
          'action': address,
          'order': items.length + 1,
          'isActive': true,
          'updatedAt': now,
        }
      ));
    }

    for (final item in items) {
      batch.set(
        FirestorePaths.churchContactItems(_firestore, churchId).doc(item.id),
        item.data,
      );
    }
  }

  void _seedChurchGroups({
    required WriteBatch batch,
    required String churchId,
    required Object now,
  }) {
    for (final group in churchGroupDefinitions) {
      batch.set(
        FirestorePaths.churchGroupDoc(_firestore, churchId, group.id),
        {
          'id': group.id,
          'label': group.label,
          'updatedAt': now,
        },
      );
    }
  }

  SettableMetadata _metadataFor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
    return SettableMetadata(contentType: contentType);
  }
}

class CreateChurchException implements Exception {
  const CreateChurchException(this.code);

  final String code;
}
