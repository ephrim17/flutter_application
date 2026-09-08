import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

/// Person-owned, not church-owned (§5.1/Phase 4) — a reading plan follows
/// the person everywhere, including the guest shell, so this repository has
/// no churchId dependency.
class ReadingPlanProgressRepository {
  final FirebaseFirestore firestore;
  final String uid;

  ReadingPlanProgressRepository({
    required this.firestore,
    required this.uid,
  });

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirestorePaths.userReadingPlans(firestore, uid);

  Future<List<int>> fetchCompletedDays(String month) async {
    final doc = await _collection.doc(month.toLowerCase()).get();

    if (!doc.exists) return [];

    final data = doc.data();
    if (data == null || data['completedDays'] == null) {
      return [];
    }

    return List<int>.from(data['completedDays']);
  }

  Future<void> updateCompletedDays(
    String month,
    List<int> days,
  ) async {
    await _collection.doc(month.toLowerCase()).set({
      'completedDays': days,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
