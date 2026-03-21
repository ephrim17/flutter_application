import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/firebase_options.dart';

class CreatedAuthAccount {
  const CreatedAuthAccount({
    required this.uid,
    required this.email,
  });

  final String uid;
  final String email;
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  Future<void> createFirebaseAccount({
    required String email,
    required String password,
  }) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<CreatedAuthAccount> createFirebaseAccountForAdmin({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final secondaryAppName =
        'admin-member-${DateTime.now().microsecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: secondaryAppName,
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final createdUser = credential.user;
      if (createdUser == null) {
        throw FirebaseAuthException(
          code: 'user-creation-failed',
          message: 'Unable to create the member account.',
        );
      }

      await secondaryAuth.signOut();

      return CreatedAuthAccount(
        uid: createdUser.uid,
        email: normalizedEmail,
      );
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> deleteAccount({
    required String churchId,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed in user found.',
      );
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Unable to verify this account email.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);

    final userId = user.uid;
    await _deleteFirestoreUserData(
      churchId: churchId,
      uid: userId,
    );

    await user.delete();
  }

  Future<void> _deleteFirestoreUserData({
    required String churchId,
    required String uid,
  }) async {
    final batch = _firestore.batch();

    final readingPlans = await FirestorePaths
        .churchUserReadingPlans(_firestore, churchId, uid)
        .get();

    for (final doc in readingPlans.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(FirestorePaths.churchUserDoc(_firestore, churchId, uid));

    final globalUserDoc = await FirestorePaths.userDoc(_firestore, uid).get();
    if (globalUserDoc.exists) {
      batch.delete(globalUserDoc.reference);
    }

    await batch.commit();
  }

  Future<void> requestAccess(
      {required String name,
      required String phone,
      required String location,
      required String address,
      required String gender,
      required String category,
      required String familyId,
      required DateTime dob,
      required String authToken,
      required String churchId,
      String? familyLabel,
      String? targetUid,
      String? targetEmail,
      bool approved = false,
      bool createChurchMemberWithoutAuth = false}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null &&
        targetUid == null &&
        targetEmail == null &&
        !createChurchMemberWithoutAuth) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed in user found.',
      );
    }

    final usersRef = FirestorePaths.churchUsers(_firestore, churchId);
    final generatedDocId =
        createChurchMemberWithoutAuth ? usersRef.doc().id : null;
    final uid = targetUid ?? generatedDocId ?? currentUser!.uid;
    final email = createChurchMemberWithoutAuth
        ? (targetEmail ?? '').trim().toLowerCase()
        : (targetEmail ?? currentUser?.email ?? '').trim().toLowerCase();
    final docRef = usersRef.doc(uid);

    await docRef.set({
      'uid': uid,
      'name': name.trim(),
      'email': email,
      'phone': phone.trim(),
      'location': location.trim(),
      'address': address.trim(),
      'gender': gender.trim(),
      'category': category.trim(),
      'familyId': familyId.trim(),
      'dob': Timestamp.fromDate(dob),
      'approved': approved,
      'authToken': authToken,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (category.trim() == 'family') {
      await FirestorePaths.churchFamilies(_firestore, churchId)
          .doc(familyId.trim())
          .set({
        'familyId': familyId.trim(),
        'label': (familyLabel ?? name).trim(),
        'category': category.trim(),
        'churchId': churchId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<List<String>> getFamilyIds(String churchId) async {
    final snapshot = await FirestorePaths
        .churchFamilies(_firestore, churchId)
        .orderBy('familyId')
        .get();

    return snapshot.docs
        .map((doc) => (doc.data()['familyId'] ?? '').toString())
        .where((familyId) => familyId.isNotEmpty)
        .toList();
  }

  Future<DocumentSnapshot> getChurchUserDoc({
    required String churchId,
    required String uid,
  }) {
    return FirestorePaths.churchUserDoc(_firestore, churchId, uid).get();
  }
}
