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

  Future<void> updateMemberDetails(
    String userId, {
    required String name,
    required String phone,
    required String location,
    required String address,
    required String gender,
    required String category,
    required String familyId,
    required DateTime dob,
    String? familyLabel,
  }) async {
    await collectionRef().doc(userId).update({
      'name': name.trim(),
      'phone': phone.trim(),
      'location': location.trim(),
      'address': address.trim(),
      'gender': gender.trim(),
      'category': category.trim(),
      'familyId': familyId.trim(),
      'dob': Timestamp.fromDate(dob),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (category.trim() == 'family') {
      await FirestorePaths.churchFamilies(firestore, churchId)
          .doc(familyId.trim())
          .set({
        'familyId': familyId.trim(),
        'label': (familyLabel ?? name).trim(),
        'category': category.trim(),
        'churchId': churchId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> attachFirebaseAuthToMember(
    String existingUserId, {
    required String newUid,
    required String email,
  }) async {
    final existingDoc = await FirestorePaths
        .churchUserDoc(firestore, churchId, existingUserId)
        .get();
    if (!existingDoc.exists) {
      throw StateError('Member not found.');
    }

    final existingData = existingDoc.data() as Map<String, dynamic>;
    final newDoc = FirestorePaths.churchUserDoc(firestore, churchId, newUid);
    final batch = firestore.batch();

    batch.set(newDoc, {
      ...existingData,
      'uid': newUid,
      'email': email.trim().toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (existingUserId != newUid) {
      final readingPlans = await FirestorePaths
          .churchUserReadingPlans(firestore, churchId, existingUserId)
          .get();

      for (final doc in readingPlans.docs) {
        batch.set(
          FirestorePaths
              .churchUserReadingPlans(firestore, churchId, newUid)
              .doc(doc.id),
          doc.data(),
        );
        batch.delete(doc.reference);
      }

      batch.delete(existingDoc.reference);
    }

    await batch.commit();
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
