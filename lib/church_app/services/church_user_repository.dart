import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class ChurchUsersRepository extends ChurchScopedRepository {
  ChurchUsersRepository({
    required super.firestore,
    required super.churchId,
  });

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> updateAuthToken({
    required String uid,
    required String token,
  }) async {
    await collectionRef().doc(uid).update({
      'authToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> updateProfile({
    required String uid,
    required String phone,
    required String location,
    required String address,
    required String category,
    required String familyId,
    required List<String> churchGroupIds,
    required DateTime? dob,
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
            'churches/$churchId/users/$uid/profile/'
            'avatar_$version.${_imageExtension(profilePhoto.name)}',
          );
      await uploadedPhotoRef.putData(
        profilePhoto.bytes,
        SettableMetadata(contentType: _imageContentType(profilePhoto.name)),
      );
      profilePhotoUrl = await uploadedPhotoRef.getDownloadURL();
    } else if (removeProfilePhoto) {
      profilePhotoUrl = '';
    }

    try {
      await collectionRef().doc(uid).update({
        'phone': phone.trim(),
        'location': location.trim(),
        'address': address.trim(),
        'category': category.trim(),
        'familyId': familyId.trim(),
        'dob': dob != null ? Timestamp.fromDate(dob) : null,
        'profilePhotoUrl': profilePhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await _deletePhoto(uploadedPhotoRef);
      rethrow;
    }

    await Future.wait([
      _syncProfilePhotoToFeeds(uid, profilePhotoUrl),
      _syncProfilePhotoToGroups(
        uid: uid,
        churchGroupIds: churchGroupIds,
        profilePhotoUrl: profilePhotoUrl,
      ),
    ]);

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
      // Storage cleanup is best effort and must not make a saved profile look
      // like it failed.
    }
  }

  Future<void> _syncProfilePhotoToFeeds(
    String uid,
    String profilePhotoUrl,
  ) async {
    try {
      final results = await Future.wait([
        FirestorePaths.feedCollection(firestore, churchId)
            .where('userId', isEqualTo: uid)
            .get(),
        FirestorePaths.globalFeedCollection(firestore)
            .where('userId', isEqualTo: uid)
            .get(),
      ]);

      final references = <DocumentReference>[
        ...results.first.docs.map((doc) => doc.reference),
        ...results.last.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? const {};
          return (data['churchId'] ?? '').toString().trim() == churchId;
        }).map((doc) => doc.reference),
      ];

      for (var start = 0; start < references.length; start += 400) {
        final end =
            start + 400 < references.length ? start + 400 : references.length;
        final batch = firestore.batch();
        for (final reference in references.sublist(start, end)) {
          batch.update(reference, {'userPhoto': profilePhotoUrl});
        }
        await batch.commit();
      }
    } catch (_) {
      // The profile update remains successful even if an older feed post
      // cannot be synchronized under the current Firestore permissions.
    }
  }

  Future<void> _syncProfilePhotoToGroups({
    required String uid,
    required List<String> churchGroupIds,
    required String profilePhotoUrl,
  }) async {
    try {
      final batch = firestore.batch();
      for (final groupId in churchGroupIds) {
        final normalizedGroupId = groupId.trim();
        if (normalizedGroupId.isEmpty) continue;
        batch.update(
          FirestorePaths.churchGroupMembers(
            firestore,
            churchId,
            normalizedGroupId,
          ).doc(uid),
          {'profilePhotoUrl': profilePhotoUrl},
        );
      }
      await batch.commit();
    } catch (_) {
      // Some older group memberships may no longer exist. Their avatar will
      // fall back to initials without preventing the profile from saving.
    }
  }

  Future<String?> getExistingAuthToken(String uid) async {
    final doc = await collectionRef().doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?.authToken;
  }

  Future<void> updateDailyStreak({
    required String uid,
  }) async {
    final docRef = FirestorePaths.churchUserDoc(firestore, churchId, uid);

    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>? ?? const {};
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
        if (lastDay == today) {
          return;
        }
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
            'dayStreak': '1',
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
        'dayStreak': nextStreak.toString(),
        'lastStreakRecordedAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  CollectionReference<AppUser> collectionRef() {
    return FirestorePaths.churchUsers(firestore, churchId)
        .withConverter<AppUser>(
      fromFirestore: (snap, _) => AppUser.fromFirestore(snap.id, snap.data()!),
      toFirestore: (user, _) => user.toMap(),
    );
  }

  DocumentReference<AppUser> userDoc(String uid) {
    return collectionRef().doc(uid);
  }

  Future<String?> getUserName(String uid) async {
    try {
      final doc = await userDoc(uid).get();
      if (!doc.exists) return null;
      return doc.data()?.name;
    } catch (_) {
      return null;
    }
  }

  Stream<String?> watchUserName(String uid) {
    return userDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data()?.name;
    });
  }
}
