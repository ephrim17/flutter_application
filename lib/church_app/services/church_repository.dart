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
      return snapshot.docs
          .map((doc) => Church.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }
}