import 'package:flutter_application/church_app/services/firestore/firestore_authentication.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((_) => FirebaseAuth.instance);
    
final firestoreProvider = Provider((_) => FirebaseFirestore.instance);

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    ref.read(firebaseAuthProvider),
    ref.read(firestoreProvider),
  ),
);