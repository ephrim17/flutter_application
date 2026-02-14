import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReadingPlanProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> _uid() async {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  Future<List<int>> fetchCompletedDays(String month) async {
    final uid = await _uid();
    if (uid == null) return [];

    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('readingPlans')
        .doc(month.toLowerCase())
        .get();

    if (!doc.exists) return [];

    final data = doc.data();
    if (data == null || data['completedDays'] == null) return [];

    return List<int>.from(data['completedDays']);
  }

  Future<void> updateCompletedDays(
      String month, List<int> days) async {
    final uid = await _uid();
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('readingPlans')
        .doc(month.toLowerCase())
        .set({
      'completedDays': days,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
