// ignore_for_file: file_names

import 'package:flutter_application/church_app/services/firestore/firestore_authentication.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// TODO(user-church-decoupling): re-export only, kept so this file's existing
// importers keep compiling after the firestoreProvider collapse (KT Files/
// architecture/user-church-decoupling-migration.md §3, Phase 0). The
// canonical declaration lives in services/firestore/firestore_provider.dart —
// repoint importers there directly and delete this export once that's done.
// Three import paths for one provider is the same ambiguity that caused the
// duplication this collapse fixes.
export 'package:flutter_application/church_app/services/firestore/firestore_provider.dart'
    show firestoreProvider;

final firebaseAuthProvider =
    Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    ref.read(firebaseAuthProvider),
    ref.read(firestoreProvider),
  ),
);
