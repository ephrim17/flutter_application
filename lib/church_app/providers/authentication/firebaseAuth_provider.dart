import 'package:flutter_application/church_app/models/user/app_user_model.dart';
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

// final appUserProvider = FutureProvider<AppUser?>((ref) async {
//   final repo = ref.read(authRepositoryProvider);
//   return repo.getCurrentUser();
// });

final appUserProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);

  return auth.authStateChanges().asyncMap((user) async {
    if (user == null) return null;

    final doc =
        await firestore.collection('users').doc(user.uid).get();

    if (!doc.exists) return null;

    return AppUser.fromJson(doc.data()!);
  });
});
