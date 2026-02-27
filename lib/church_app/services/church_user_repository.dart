import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class ChurchUsersRepository extends ChurchScopedRepository {
  ChurchUsersRepository({
    required super.firestore,
    required super.churchId,
  });

  Future<void> updateAuthToken({
    required String uid,
    required String token,
  }) async {
    await collectionRef().doc(uid).update({
      'authToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> getExistingAuthToken(String uid) async {
    final doc = await collectionRef().doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?.authToken;
  }

  CollectionReference<AppUser> collectionRef() {
    return FirestorePaths.churchUsers(firestore, churchId)
        .withConverter<AppUser>(
      fromFirestore: (snap, _) => AppUser.fromJson(snap.data()!),
      toFirestore: (user, _) => user.toMap(),
    );
  }

  DocumentReference<AppUser> userDoc(String uid) {
    return collectionRef().doc(uid);
  }

  Future<String?> getUserName(String uid) async {
    try {
      final doc = await userDoc(uid).get();
      if (!doc.exists) return null;
      return doc.data()?.name;
    } catch (_) {
      return null;
    }
  }

  Stream<String?> watchUserName(String uid) {
    return userDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data()?.name;
    });
  }
}
