import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/models/user_identity_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

/// A person's membership in one church — `churches/{cid}/members/{docId}`.
/// See KT Files/architecture/user-church-decoupling-migration.md §5.1.
class ChurchMembershipRepository extends ChurchScopedRepository {
  ChurchMembershipRepository({
    required super.firestore,
    required super.churchId,
  });

  DocumentReference<Map<String, dynamic>> doc(String docId) {
    return FirestorePaths.churchMemberDoc(firestore, churchId, docId);
  }

  Stream<ChurchMembership?> watch(String docId) {
    return doc(docId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ChurchMembership.fromFirestore(snap.id, churchId, snap.data()!);
    });
  }

  Future<ChurchMembership?> get(String docId) async {
    final snap = await doc(docId).get();
    if (!snap.exists) return null;
    return ChurchMembership.fromFirestore(snap.id, churchId, snap.data()!);
  }

  /// Request access (§5.5) — the short, church-specific step. Self-signup
  /// only; the 4-step admin form keeps using its own path
  /// (login_request_screen.dart, §5.5/§9.3).
  Future<void> requestAccess({
    required String uid,
    required UserIdentity identity,
    required String category,
    required String familyId,
    required List<String> churchGroupIds,
  }) async {
    await doc(uid).set({
      'uid': uid,
      'linkedUid': uid,
      'approved': false,
      'role': 'user',
      'category': category.trim(),
      'familyId': familyId.trim(),
      'churchGroupIds': churchGroupIds,
      'joinedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
      // Seeded from identity at creation; kept fresh afterward only by the
      // Phase 6 fan-out (§9.2) — never by a client update.
      'displayName': identity.name,
      'displayEmail': identity.email,
      'displayPhone': identity.phone,
      'displayPhotoUrl': identity.profilePhotoUrl,
      'displayDob':
          identity.dob != null ? Timestamp.fromDate(identity.dob!) : null,
      'displayGender': identity.gender,
      'displayWeddingDay': identity.weddingDay != null
          ? Timestamp.fromDate(identity.weddingDay!)
          : null,
      'displayMaritalStatus': identity.maritalStatus,
      'displayEducationalQualification': identity.educationalQualification,
      'displayTalentsAndGifts': identity.talentsAndGifts,
      'identitySyncedAt': FieldValue.serverTimestamp(),
    });
  }
}
