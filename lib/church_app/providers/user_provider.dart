import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/models/user_identity_model.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A member's cached display name for a given uid, scoped to the current
/// church (e.g. a feed/prayer author). Reads the membership cache, not
/// identity — per §9.2, that's the whole point of the cache: no per-member
/// join. Doc id equals uid for a linked member (§9.7); this naturally
/// returns null for a random-id/unlinked doc, which never matches.
final churchMemberNameProvider =
    FutureProvider.family<String?, String>((ref, uid) async {
  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null) return null;

  final doc = await FirestorePaths.churchMemberDoc(
    ref.read(firestoreProvider),
    churchId,
    uid,
  ).get();
  if (!doc.exists) return null;
  final name = (doc.data()?['displayName'] as String?)?.trim();
  return name?.isEmpty ?? true ? null : name;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Every membership the signed-in user has, across every church —
/// self-discovery via the collectionGroup('members') rule (§5.2). This is
/// the authoritative "do I have an approved membership anywhere" signal for
/// the entry gate (§5.4): it covers all four no-membership situations
/// (§5.3) uniformly, unlike currentMembershipProvider, which is scoped to
/// whatever church happens to be locally selected and can't tell "never
/// requested" apart from "removed from my only church".
final myMembershipsProvider =
    StreamProvider<List<ChurchMembership>>((ref) async* {
  final firebaseUser = ref.watch(authStateProvider).value;
  if (firebaseUser == null) {
    yield const [];
    return;
  }
  yield* ref
      .read(firestoreProvider)
      .collectionGroup(FirestorePaths.members)
      .where('uid', isEqualTo: firebaseUser.uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final churchId = doc.reference.parent.parent?.id ?? '';
            return ChurchMembership.fromFirestore(
                doc.id, churchId, doc.data());
          }).toList());
});

/// The canonical, church-independent person record for the signed-in user
/// (§5.1). No churchId dependency — this is what makes the guest shell
/// possible (§5.3/§5.4).
final userIdentityProvider = StreamProvider<UserIdentity?>((ref) async* {
  final firebaseUser = ref.watch(authStateProvider).value;
  if (firebaseUser == null) {
    yield null;
    return;
  }
  yield* FirestorePaths.userDoc(ref.read(firestoreProvider), firebaseUser.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return UserIdentity.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
  });
});

/// The signed-in user's membership in the currently selected church (§5.1).
/// Replaces appUserProvider/getCurrentUserProvider — those returned one
/// merged AppUser; identity and membership are now separate documents and
/// separate providers on purpose (D1's whole point).
final currentMembershipProvider =
    StreamProvider<ChurchMembership?>((ref) async* {
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
  yield* FirestorePaths.churchMemberDoc(
    ref.read(firestoreProvider),
    churchId,
    firebaseUser.uid,
  ).snapshots().map((doc) {
    if (!doc.exists) return null;
    return ChurchMembership.fromFirestore(
      doc.id,
      churchId,
      doc.data() as Map<String, dynamic>,
    );
  });
});
