

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
  return FirestorePaths
      .churchUsers(firestore, churchId)
      .withConverter<AppUser>(
        fromFirestore: (snap, _) =>
            AppUser.fromFirestore(
              snap.id,               // 👈 document ID
              snap.data()!,
            ),
        toFirestore: (user, _) => user.toMap(),
      );
}

  Stream<List<AppUser>> getMembers() {
    return collectionRef()
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => doc.data()).toList(),
        );
  }

  Future<void> approveMember(String userId, bool value) {
    return collectionRef().doc(userId).update({
      'approved': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}