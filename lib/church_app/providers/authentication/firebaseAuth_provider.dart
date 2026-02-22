import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_authentication.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

final firestoreProvider =
    Provider((_) => FirebaseFirestore.instance);

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    ref.read(firebaseAuthProvider),
    ref.read(firestoreProvider),
  ),
);

final getCurrentUserProvider = FutureProvider<AppUser?>((ref) async {
  ref.keepAlive();

  final repo = ref.read(authRepositoryProvider);
  return repo.getCurrentUser();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final appUserProvider = StreamProvider<AppUser?>((ref) {
  final firebaseUser = ref.watch(authStateProvider).value;

  if (firebaseUser == null) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(firebaseUser.uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return null;
        return AppUser.fromJson(doc.data()!);
      });
});