import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class MembersRepository extends ChurchScopedRepository {
  MembersRepository({
    required super.firestore,
    required super.churchId,
  });

  CollectionReference<AppUser> collectionRef() {
    return FirestorePaths.churchUsers(firestore, churchId)
        .withConverter<AppUser>(
      fromFirestore: (snap, _) => AppUser.fromFirestore(
        snap.id, // 👈 document ID
        snap.data()!,
      ),
      toFirestore: (user, _) => user.toMap(),
    );
  }

  Stream<List<AppUser>> getMembers() {
    return collectionRef().snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
        );
  }

  Future<void> approveMember(String userId, bool value) {
    return collectionRef().doc(userId).update({
      'approved': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMemberCategory(
    String userId, {
    required String category,
    required String familyId,
  }) {
    return collectionRef().doc(userId).update({
      'category': category.trim().toLowerCase(),
      'familyId': familyId.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMember(String userId) {
    return _deleteChurchUserData(userId);
  }

  Future<void> _deleteChurchUserData(String userId) async {
    await _deleteCollection(
      FirestorePaths.churchUserReadingPlans(firestore, churchId, userId),
    );
    await FirestorePaths.churchUserDoc(firestore, churchId, userId).delete();
  }

  Future<void> _deleteCollection(CollectionReference collectionRef) async {
    while (true) {
      final snapshot = await collectionRef.limit(50).get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
  }
}
