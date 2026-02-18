

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class MembersRepository {
  final _ref = FirebaseFirestore.instance.collection(FirestorePaths.users);

  Stream<List<AppUser>> getMembers() {
    return _ref
        //.orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AppUser.fromFirestore(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  Future<void> approveMember(String userId, bool value) {
    return _ref.doc(userId).update({'approved': value});
  }
}
