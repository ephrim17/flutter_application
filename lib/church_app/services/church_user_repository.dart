import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class ChurchUsersRepository extends ChurchScopedRepository {
  ChurchUsersRepository({
    required super.firestore,
    required super.churchId,
  });

  Future<void> updateAuthToken({
    required String uid,
    required String token,
  }) async {
    await collectionRef().doc(uid).update({
      'authToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfile({
    required String uid,
    required String phone,
    required String location,
    required String address,
    required String category,
    required String familyId,
    required DateTime? dob,
  }) async {
    await collectionRef().doc(uid).update({
      'phone': phone.trim(),
      'location': location.trim(),
      'address': address.trim(),
      'category': category.trim(),
      'familyId': familyId.trim(),
      'dob': dob != null ? Timestamp.fromDate(dob) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
              DateTime(lastRecorded.year, lastRecorded.month, lastRecorded.day) ==
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
