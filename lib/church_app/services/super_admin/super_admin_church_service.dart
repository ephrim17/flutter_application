import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
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
    this.registrationSource = 'super_admin',
    this.adminUid,
    this.adminName,
    this.adminEmail,
    this.adminPhone,
    this.features = const <String, bool>{},
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
  final String registrationSource;
  final String? adminUid;
  final String? adminName;
  final String? adminEmail;
  final String? adminPhone;
  final Map<String, bool> features;
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
    this.features = const <String, bool>{},
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
  final Map<String, bool> features;
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

  static const Map<String, bool> defaultFeatureFlags = <String, bool>{
    'membersEnabled': true,
    'eventsEnabled': true,
    'dashboardEnabled': true,
    'financialDashboardEnabled': false,
    'equipmentEnabled': false,
    'studioEnabled': true,
    'globalFeedEnabled': true,
    'bibleSwipeFetchEnabled': true,
  };

  static Map<String, bool> normalizeFeatureFlags(Map<String, bool> features) {
    return <String, bool>{
      ...defaultFeatureFlags,
      ...features,
    };
  }

  Future<bool> churchExists(String churchId) async {
    final doc =
        await FirestorePaths.churchDoc(_firestore, churchId.trim()).get();
    return doc.exists;
  }

  Future<bool> churchEmailExists(
    String email, {
    String? excludeChurchId,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return false;

    final snapshot = await _firestore
        .collection(FirestorePaths.churches)
        .where('email', isEqualTo: normalizedEmail)
        .limit(10)
        .get();

    for (final doc in snapshot.docs) {
      if (excludeChurchId == null || doc.id != excludeChurchId.trim()) {
        return true;
      }
    }

    return false;
  }

  Future<void> createChurch(CreateChurchInput input) async {
    final churchId = input.churchId.trim();
    final churchDoc = FirestorePaths.churchDoc(_firestore, churchId);
    if (await churchExists(churchId)) {
      throw const CreateChurchException('duplicate-id');
    }
    if (await churchEmailExists(input.email)) {
      throw const CreateChurchException('duplicate-email');
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
    final pastorDocRef =
        FirestorePaths.churchPastors(_firestore, churchId).doc();

    batch.set(churchDoc, {
      'name': input.name.trim(),
      'pastorName': input.pastorName.trim(),
      'pastorPhoto': pastorPhotoUrl,
      'address': input.address.trim(),
      'contact': input.contact.trim(),
      'email': normalizedChurchEmail,
      'logo': logoUrl,
      'enabled': input.enabled,
      'registrationSource': input.registrationSource.trim().isEmpty
          ? 'super_admin'
          : input.registrationSource.trim(),
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
          ...normalizeFeatureFlags(input.features),
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
        'superAdminDisabled': false,
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
        pastorDocRef,
        {
          'title': input.pastorName.trim(),
          'contact': input.contact.trim(),
          'imageUrl': pastorPhotoUrl,
          'primary': true,
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

    final shouldNotifyOnCreate =
        input.registrationSource.trim() == 'super_admin';
    if (shouldNotifyOnCreate) {
      await _queueAdminNotificationSafely(
        recipients: _normalizeRecipients([
          input.adminEmail,
          normalizedChurchEmail,
        ]),
        template: 'church_created',
        subject: 'Church created: ${input.name.trim()}',
        text: _buildChurchCreatedText(
          churchName: input.name.trim(),
          churchId: churchId,
          enabled: input.enabled,
        ),
        data: {
          'churchId': churchId,
          'churchName': input.name.trim(),
          'enabled': input.enabled,
          'registrationSource': input.registrationSource.trim(),
        },
      );
    }
  }

  Future<void> updateChurch(UpdateChurchInput input) async {
    final churchId = input.churchId.trim();
    final churchDoc = FirestorePaths.churchDoc(_firestore, churchId);
    final existingChurchSnapshot = await churchDoc.get();
    final existingChurchData =
        (existingChurchSnapshot.data() as Map<String, dynamic>?) ?? const {};
    final now = FieldValue.serverTimestamp();
    final normalizedChurchEmail = input.email.trim().toLowerCase();
    final pastorDocRef = await _resolvePastorDocRef(churchId);

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
        'features': normalizeFeatureFlags(input.features),
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
      pastorDocRef,
      {
        'title': input.pastorName.trim(),
        'contact': input.contact.trim(),
        'imageUrl': pastorPhotoUrl,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    final previousEnabled =
        existingChurchData['enabled'] as bool? ?? input.enabled;
    if (previousEnabled != input.enabled) {
      await _queueStatusNotification(
        churchId: churchId,
        churchName: input.name.trim(),
        fallbackEmail: normalizedChurchEmail,
        enabled: input.enabled,
      );
    }
  }

  Future<void> updateChurchEnabled({
    required String churchId,
    required bool enabled,
  }) async {
    final normalizedChurchId = churchId.trim();
    final churchRef = FirestorePaths.churchDoc(_firestore, normalizedChurchId);
    final churchSnapshot = await churchRef.get();
    final churchData = churchSnapshot.data() as Map<String, dynamic>?;

    if (!churchSnapshot.exists || churchData == null) {
      throw const CreateChurchException('church-not-found');
    }

    final previousEnabled = churchData['enabled'] as bool? ?? false;
    final churchName = (churchData['name'] as String? ?? '').trim();
    final fallbackEmail =
        (churchData['email'] as String? ?? '').trim().toLowerCase();

    final batch = _firestore.batch();
    batch.set(
      churchRef,
      {
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      FirestorePaths.churchAppConfig(_firestore, normalizedChurchId),
      {
        'superAdminDisabled': !enabled,
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    if (previousEnabled == enabled) return;

    await _queueStatusNotification(
      churchId: normalizedChurchId,
      churchName: churchName,
      fallbackEmail: fallbackEmail,
      enabled: enabled,
    );
  }

  Future<void> updateChurchFeature({
    required String churchId,
    required String featureKey,
    required bool enabled,
  }) async {
    await FirestorePaths.churchAppConfig(_firestore, churchId.trim()).set(
      {
        'features': {
          featureKey.trim(): enabled,
        },
      },
      SetOptions(merge: true),
    );
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

  Future<DocumentReference<Object?>> _resolvePastorDocRef(
    String churchId,
  ) async {
    final pastorsRef = FirestorePaths.churchPastors(_firestore, churchId);
    final snapshot = await pastorsRef.limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.reference;
    }
    return pastorsRef.doc();
  }

  Future<String> _uploadPastorPhoto({
    required String churchId,
    required PickedImageData imageFile,
  }) async {
    final fileName = imageFile.name.trim().isEmpty
        ? 'pastor_photo.jpg'
        : imageFile.name.trim();
    final storageRef =
        _storage.ref().child('churches/$churchId/pastorPhotos/$fileName');
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

  Future<void> _queueStatusNotification({
    required String churchId,
    required String churchName,
    required String fallbackEmail,
    required bool enabled,
  }) async {
    final recipients = await _getAdminRecipients(
      churchId: churchId,
      fallbackEmail: fallbackEmail,
    );
    await _queueAdminNotificationSafely(
      recipients: recipients,
      template: enabled ? 'church_enabled' : 'church_disabled',
      subject: 'Church ${enabled ? 'enabled' : 'disabled'}: $churchName',
      text: _buildChurchStatusText(
        churchName: churchName,
        churchId: churchId,
        enabled: enabled,
      ),
      data: {
        'churchId': churchId,
        'churchName': churchName,
        'enabled': enabled,
      },
    );
  }

  Future<List<String>> _getAdminRecipients({
    required String churchId,
    required String fallbackEmail,
  }) async {
    final configSnapshot =
        await FirestorePaths.churchAppConfig(_firestore, churchId).get();
    final configData = configSnapshot.data() ?? const <String, dynamic>{};
    final adminEmails = List<String>.from(configData['admins'] ?? const []);

    return _normalizeRecipients([
      ...adminEmails,
      fallbackEmail,
    ]);
  }

  List<String> _normalizeRecipients(Iterable<String?> values) {
    return values
        .map((value) => (value ?? '').trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<void> _queueAdminNotificationSafely({
    required List<String> recipients,
    required String template,
    required String subject,
    required String text,
    required Map<String, Object?> data,
  }) async {
    if (recipients.isEmpty) return;

    try {
      await FirestorePaths.mailQueue(_firestore).add({
        'kind': 'super_admin_notification',
        'template': template,
        'to': recipients,
        'subject': subject,
        'text': text,
        'html': _textToHtml(text),
        'data': data,
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to queue super admin notification: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _buildChurchCreatedText({
    required String churchName,
    required String churchId,
    required bool enabled,
  }) {
    return [
      'Hello Admin,',
      '',
      'Your church "$churchName" has been created from the super admin dashboard.',
      'Church ID: $churchId',
      'Current status: ${enabled ? 'enabled' : 'disabled'}',
      '',
      'You can now continue setting up the church in the app.',
    ].join('\n');
  }

  String _buildChurchStatusText({
    required String churchName,
    required String churchId,
    required bool enabled,
  }) {
    return [
      'Hello Admin,',
      '',
      'Your church "$churchName" has been ${enabled ? 'enabled' : 'disabled'} from the super admin dashboard.',
      'Church ID: $churchId',
      '',
      enabled
          ? 'Access to the church is active again.'
          : 'Access to the church is currently turned off.',
    ].join('\n');
  }

  String _textToHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('\n', '<br>');
  }
}

class CreateChurchException implements Exception {
  const CreateChurchException(this.code);

  final String code;
}
