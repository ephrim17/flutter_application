import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class PrayerRepository {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// ADD PRAYER
  Future<void> addPrayer({
    required String title,
    required String description,
    required bool isAnonymous,
    required DateTime expiryDate,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final now = DateTime.now();

    // Normalize to date-only (remove time component)
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );

    final maxDate = today.add(const Duration(days: 30));

    if (selectedDate.isBefore(today) || selectedDate.isAfter(maxDate)) {
      throw Exception("Expiry date must be within 30 days");
    }

    await _firestore.collection(FirestorePaths.prayerRequests).add({
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

    // Normalize to date-only (remove time component)
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );

    final maxDate = today.add(const Duration(days: 30));

    if (selectedDate.isBefore(today) || selectedDate.isAfter(maxDate)) {
      throw Exception("Expiry date must be within 30 days");
    }

    await _firestore.collection(FirestorePaths.prayerRequests).doc(prayerId).update({
      'title': title.trim(),
      'description': description.trim(),
      'isAnonymous': isAnonymous,
      'expiryDate': Timestamp.fromDate(selectedDate),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  Stream<List<PrayerRequest>> watchMyPrayers() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    return _firestore
        .collection(FirestorePaths.prayerRequests)
        .where('userId', isEqualTo: uid)
        .where(
          'expiryDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
        )
        .orderBy('expiryDate') // required when using range filter
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PrayerRequest.fromDoc).toList());
  }

  Stream<List<PrayerRequest>> getAllPrayers() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    return _firestore
        .collection(FirestorePaths.prayerRequests)
        .where(
          'expiryDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
        )
        .orderBy('expiryDate')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PrayerRequest.fromDoc).toList());
  }

  Future<void> deletePrayer(String prayerId) async {
    await _firestore.collection(FirestorePaths.prayerRequests).doc(prayerId).delete();
  }
}
