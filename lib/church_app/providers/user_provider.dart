import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/church_user_repository.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final churchUserNameProvider =
    FutureProvider.family<String?, String>((ref, uid) async {
  final churchId = await ref.watch(currentChurchIdProvider.future);

  if (churchId == null) return null;

  final repo = ChurchUsersRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );

  return repo.getUserName(uid);
});

final getCurrentUserProvider = FutureProvider<AppUser?>((ref) async {
  ref.keepAlive();
  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null) return null;
  return getCurrentUser(churchId);
});

Future<AppUser?> getCurrentUser(String churchId) async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final user = auth.currentUser;
  if (user == null) return null;

  final doc =
      await FirestorePaths.churchUserDoc(firestore, churchId, user.uid).get();

  if (!doc.exists) return null;

  return AppUser.fromJson(doc.data() as Map<String, dynamic>);
}

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final appUserProvider = StreamProvider<AppUser?>((ref) async* {
  final firebaseUser = ref.watch(authStateProvider).value;

  if (firebaseUser == null) {
    yield null;
    return;
  }

  final churchId = await ref.watch(currentChurchIdProvider.future);

  if (churchId == null) {
    yield null;
    return;
  }
  yield* FirestorePaths.churchUserDoc(
    FirebaseFirestore.instance,
    churchId,
    firebaseUser.uid,
  ).snapshots().map((doc) {
    if (!doc.exists) return null;
    return AppUser.fromJson(doc.data() as Map<String, dynamic>);
  });
});
