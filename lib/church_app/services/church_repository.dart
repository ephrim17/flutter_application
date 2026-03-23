import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/church_model.dart';

class ChurchRepository {
  final FirebaseFirestore _firestore;

  ChurchRepository(this._firestore);

  Stream<List<Church>> getEnabledChurches() {
    return _firestore
        .collection('churches')
        .where('enabled', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final churches = snapshot.docs
          .map((doc) => Church.fromFirestore(doc.id, doc.data()))
          .toList();

      churches.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      return churches;
    });
  }

  Stream<List<Church>> getAllChurches() {
    return _firestore.collection('churches').snapshots().map((snapshot) {
      final churches = snapshot.docs
          .map((doc) => Church.fromFirestore(doc.id, doc.data()))
          .toList();

      churches.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      return churches;
    });
  }

  Future<void> updateChurchEnabled({
    required String churchId,
    required bool enabled,
  }) {
    return _firestore.collection('churches').doc(churchId).update({
      'enabled': enabled,
    });
  }
}
