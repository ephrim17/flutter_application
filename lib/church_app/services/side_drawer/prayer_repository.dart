import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';

class PrayerRepository {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Add prayer
  Future<void> addPrayer({
    required String title,
    required String description,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    await _firestore.collection('prayer_requests').add({
      'userId': user.uid, // 🔥 store UID
      'email': user.email,
      'title': title,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream user's prayers
  Stream<List<PrayerRequest>> watchMyPrayers() {
    final uid = _uid;

    if (uid == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('prayer_requests')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(PrayerRequest.fromDoc).toList(),
        );
  }

  /// Stream all prayers (ADMIN)
  Stream<List<PrayerRequest>> getAllPrayers() {
    return _firestore
        .collection('prayer_requests')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(PrayerRequest.fromDoc).toList(),
        );
  }

  /// Delete prayer
  Future<void> deletePrayer(String prayerId) async {
    await _firestore.collection('prayer_requests').doc(prayerId).delete();
  }
}
