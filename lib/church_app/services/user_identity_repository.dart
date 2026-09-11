import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/models/user_identity_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

/// The canonical, church-independent person record — `users/{uid}`. See
/// KT Files/architecture/user-church-decoupling-migration.md §5.1.
class UserIdentityRepository {
  UserIdentityRepository({required this.firestore});

  final FirebaseFirestore firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirestorePaths.userDoc(firestore, uid);

  /// Signup (D5) — captures only the essentials; the rest is completed
  /// after approval (§5.5).
  Future<void> createIdentity({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required DateTime? dob,
    required String gender,
  }) async {
    await _doc(uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'dob': dob != null ? Timestamp.fromDate(dob) : null,
      'gender': gender.trim(),
      'profileComplete': false,
      'emailVerified': false,
      'schemaVersion': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<UserIdentity?> watch(String uid) {
    return _doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserIdentity.fromFirestore(doc.id, doc.data()!);
    });
  }

  Future<UserIdentity?> get(String uid) async {
    final doc = await _doc(uid).get();
    if (!doc.exists) return null;
    return UserIdentity.fromFirestore(doc.id, doc.data()!);
  }

  /// Post-approval completion step (§5.5) — never gates church access.
  Future<String> updateProfile({
    required String uid,
    required String phone,
    required String location,
    required String address,
    required DateTime? dob,
    required String maritalStatus,
    required DateTime? weddingDay,
    required String educationalQualification,
    required List<String> talentsAndGifts,
    required String existingProfilePhotoUrl,
    PickedImageData? profilePhoto,
    bool removeProfilePhoto = false,
  }) async {
    var profilePhotoUrl = existingProfilePhotoUrl.trim();
    Reference? uploadedPhotoRef;
    Reference? previousPhotoRef;
    if (profilePhotoUrl.isNotEmpty) {
      try {
        previousPhotoRef = _storage.refFromURL(profilePhotoUrl);
      } catch (_) {
        previousPhotoRef = null;
      }
    }

    if (profilePhoto != null) {
      final version = DateTime.now().microsecondsSinceEpoch;
      uploadedPhotoRef = _storage.ref().child(
            'users/$uid/profile/avatar_$version.${_imageExtension(profilePhoto.name)}',
          );
      await uploadedPhotoRef.putData(
        profilePhoto.bytes,
        SettableMetadata(contentType: _imageContentType(profilePhoto.name)),
      );
      profilePhotoUrl = await uploadedPhotoRef.getDownloadURL();
    } else if (removeProfilePhoto) {
      profilePhotoUrl = '';
    }

    final trimmedLocation = location.trim();
    final trimmedAddress = address.trim();
    final trimmedMaritalStatus = maritalStatus.trim();
    try {
      await _doc(uid).update({
        'phone': phone.trim(),
        'location': trimmedLocation,
        'address': trimmedAddress,
        'dob': dob != null ? Timestamp.fromDate(dob) : null,
        'maritalStatus': trimmedMaritalStatus,
        'weddingDay':
            weddingDay != null ? Timestamp.fromDate(weddingDay) : null,
        'educationalQualification': educationalQualification.trim(),
        'talentsAndGifts': talentsAndGifts,
        'profilePhotoUrl': profilePhotoUrl,
        'profileComplete': trimmedLocation.isNotEmpty &&
            trimmedAddress.isNotEmpty &&
            trimmedMaritalStatus.isNotEmpty,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await _deletePhoto(uploadedPhotoRef);
      rethrow;
    }

    if (profilePhoto != null || removeProfilePhoto) {
      if (previousPhotoRef?.fullPath != uploadedPhotoRef?.fullPath) {
        await _deletePhoto(previousPhotoRef);
      }
    }
    return profilePhotoUrl;
  }

  String _imageExtension(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'png' || 'webp' || 'gif' || 'jpg' || 'jpeg' => extension,
      _ => 'jpg',
    };
  }

  String _imageContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  Future<void> _deletePhoto(Reference? reference) async {
    if (reference == null) return;
    try {
      await reference.delete();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') return;
    }
  }

  /// Global — one streak per person, not per membership (D4). Counts any
  /// day the app is opened, including in the guest shell.
  Future<void> updateDailyStreak(String uid) async {
    final docRef = _doc(uid);

    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? const {};
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final rawLastRecorded = data['lastStreakRecordedAt'];
      final lastRecorded = rawLastRecorded is Timestamp
          ? rawLastRecorded.toDate()
          : rawLastRecorded is DateTime
              ? rawLastRecorded
              : null;

      if (lastRecorded != null) {
        final lastDay =
            DateTime(lastRecorded.year, lastRecorded.month, lastRecorded.day);
        if (lastDay == today) return;
      }

      final yesterday = today.subtract(const Duration(days: 1));
      final rawDayStreak = data['dayStreak'];
      final currentStreak = rawDayStreak is num
          ? rawDayStreak.round()
          : rawDayStreak is String
              ? int.tryParse(rawDayStreak.trim()) ?? 0
              : 0;

      if (lastRecorded == null && currentStreak <= 0) {
        transaction.set(
          docRef,
          {
            'dayStreak': 1,
            'lastStreakRecordedAt': Timestamp.fromDate(now),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return;
      }

      final nextStreak = lastRecorded != null &&
              DateTime(lastRecorded.year, lastRecorded.month,
                      lastRecorded.day) ==
                  yesterday
          ? currentStreak + 1
          : 1;

      transaction.update(docRef, {
        'dayStreak': nextStreak,
        'lastStreakRecordedAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setLastActiveChurchId(String uid, String? churchId) async {
    await _doc(uid).update({'lastActiveChurchId': churchId});
  }

  /// Written every launch and on onTokenRefresh, regardless of selected
  /// church (§4.1 Device, Phase 5).
  Future<void> registerDevice({
    required String uid,
    required String installationId,
    required String fcmToken,
    required String platform,
  }) async {
    await FirestorePaths.userDevices(firestore, uid).doc(installationId).set({
      'uid': uid,
      'fcmToken': fcmToken,
      'platform': platform,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
