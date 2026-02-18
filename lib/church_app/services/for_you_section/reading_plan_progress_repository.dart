import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class ReadingPlanProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> _uid() async {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  Future<List<int>> fetchCompletedDays(String month) async {
    final uid = await _uid();
    if (uid == null) return [];

    final doc = await FirestorePaths
    .userReadingPlans(_firestore, uid)
        .doc(month.toLowerCase())
        .get();

    if (!doc.exists) return [];

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null || data['completedDays'] == null) return [];

    return List<int>.from(data['completedDays']);
  }

  Future<void> updateCompletedDays(
      String month, List<int> days) async {
    final uid = await _uid();
    if (uid == null) return;

    await FirestorePaths.userReadingPlans(_firestore, uid)
        .doc(month.toLowerCase())
        .set({
      'completedDays': days,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
