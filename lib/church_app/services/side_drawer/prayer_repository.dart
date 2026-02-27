import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class PrayerRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final String churchId;

  PrayerRepository({
    required this.firestore,
    required this.auth,
    required this.churchId,
  });

  String? get _uid => auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> collectionRef() {
    return FirestorePaths.churchPrayerRequests(firestore, churchId);
  }

  /// ADD PRAYER
  Future<void> addPrayer({
    required String title,
    required String description,
    required bool isAnonymous,
    required DateTime expiryDate,
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final maxDate = today.add(const Duration(days: 30));

    if (selectedDate.isBefore(today) || selectedDate.isAfter(maxDate)) {
      throw Exception("Expiry date must be within 30 days");
    }

    await collectionRef().add({
      'userId': user.uid,
      'email': user.email,
      'title': title.trim(),
      'description': description.trim(),
      'isAnonymous': isAnonymous,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'expiryDate': Timestamp.fromDate(selectedDate),
    });
  }

  /// UPDATE PRAYER
  Future<void> updatePrayer({
    required String prayerId,
    required String title,
    required String description,
    required bool isAnonymous,
    required DateTime expiryDate,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final maxDate = today.add(const Duration(days: 30));

    if (selectedDate.isBefore(today) || selectedDate.isAfter(maxDate)) {
      throw Exception("Expiry date must be within 30 days");
    }

    await collectionRef().doc(prayerId).update({
      'title': title.trim(),
      'description': description.trim(),
      'isAnonymous': isAnonymous,
      'expiryDate': Timestamp.fromDate(selectedDate),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// WATCH MY PRAYERS
  Stream<List<PrayerRequest>> watchMyPrayers() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    return collectionRef()
        .where('userId', isEqualTo: uid)
        .where(
          'expiryDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
        )
        .orderBy('expiryDate')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(PrayerRequest.fromDoc).toList(),
        );
  }

  /// WATCH ALL ACTIVE PRAYERS
  Stream<List<PrayerRequest>> getAllPrayers() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    return collectionRef()
        .where(
          'expiryDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
        )
        .orderBy('expiryDate')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(PrayerRequest.fromDoc).toList(),
        );
  }

  Future<void> deletePrayer(String prayerId) {
    return collectionRef().doc(prayerId).delete();
  }
}