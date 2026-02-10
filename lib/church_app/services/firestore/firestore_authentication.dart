import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';

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
  

  Future<void> requestAccess({
    required String name,
    required String email,
    required String password,
    required String phone,
    required DateTime dob,
    required String authToken
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;

    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'approved': false,
      'createdAt': FieldValue.serverTimestamp(),
      'dob': dob,
      'phone': phone,
      'authToken': authToken
    });
  }

   Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc =
        await _firestore.collection('users').doc(user.uid).get();

    if (!doc.exists) return null;

    return AppUser.fromMap(doc.id, doc.data()!);
  }
}