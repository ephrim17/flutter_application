import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Login failed');
    }
  }

  Future<void> requestAccess(
      {required String name,
      required String email,
      required String password,
      required String phone,
      required DateTime dob,
      required String authToken,
      required String churchId}) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;

    await FirestorePaths.churchUserDoc(
      _firestore,
      churchId,
      uid,
    ).set({
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'dob': Timestamp.fromDate(dob),
      'approved': false,
      'authToken': authToken,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}