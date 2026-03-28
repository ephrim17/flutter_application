import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/church_model.dart';

class ChurchRepository {
  final FirebaseFirestore _firestore;
  static const int defaultChurchPageSize = 20;

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

  Future<ChurchPageResult> fetchChurchPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = defaultChurchPageSize,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('churches')
        .orderBy('name')
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final churches = snapshot.docs
        .map((doc) => Church.fromFirestore(doc.id, doc.data()))
        .toList(growable: false);

    return ChurchPageResult(
      churches: churches,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<Church?> getChurchById(String churchId) async {
    final snapshot = await _firestore.collection('churches').doc(churchId).get();
    if (!snapshot.exists) return null;
    return Church.fromFirestore(
      snapshot.id,
      snapshot.data() ?? <String, dynamic>{},
    );
  }

  Future<void> updateChurchDiscoveryDetails({
    required String churchId,
    required String name,
    required String pastorName,
    required String address,
    required String contact,
    required String email,
    required String facebookLink,
    required String instagramLink,
    required String youtubeLink,
  }) async {
    await _firestore.collection('churches').doc(churchId).set({
      'name': name.trim(),
      'pastorName': pastorName.trim(),
      'address': address.trim(),
      'contact': contact.trim(),
      'email': email.trim(),
      'facebookLink': facebookLink.trim(),
      'instagramLink': instagramLink.trim(),
      'youtubeLink': youtubeLink.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateChurchEnabled({
    required String churchId,
    required bool enabled,
  }) async {
    final batch = _firestore.batch();
    final churchRef = _firestore.collection('churches').doc(churchId);
    final appConfigRef = _firestore
        .collection('churches')
        .doc(churchId)
        .collection('config')
        .doc('app');

    batch.update(churchRef, {
      'enabled': enabled,
    });
    batch.set(
      appConfigRef,
      {
        'superAdminDisabled': !enabled,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}

class ChurchPageResult {
  const ChurchPageResult({
    required this.churches,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<Church> churches;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}
