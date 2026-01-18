import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/models/prayer_request/prayer_request_model.dart';

class PrayerRepository {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.email!;

  /// Add prayer
  Future<void> addPrayer({
    required String title,
    required String description,
  }) async {
    await _firestore.collection('prayer_requests').add({
      'userId': _uid,
      'title': title,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream user's prayers
  Stream<List<PrayerRequest>> watchMyPrayers() {
    return _firestore
        .collection('prayer_requests')
        .where('userId', isEqualTo: _uid)
        //.orderBy('createdAt', descending: true)
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
