import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application/church_app/helpers/church_group_definitions.dart';
import 'package:flutter_application/church_app/models/text_content_defaults.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/firebase_options.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

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
          message: defaultChurchTextContents['auth.member_creation_failed'],
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

  Future<void> sendPasswordSetupEmail({
    required String email,
    String churchName = '',
  }) async {
    await _sendCustomPasswordEmail(
      email: email,
      churchName: churchName,
      mode: 'setup',
    );
  }

  Future<void> sendCustomPasswordResetEmail({
    required String email,
    String churchName = '',
  }) async {
    await requestPasswordResetCode(
      email: email,
      churchName: churchName,
    );
  }

  Future<void> requestPasswordResetCode({
    required String email,
    String churchName = '',
  }) async {
    await _postPasswordResetFunction(
      functionName: 'requestPasswordResetCode',
      body: {
        'email': email.trim().toLowerCase(),
        'churchName': churchName.trim(),
      },
    );
  }

  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    final data = await _postPasswordResetFunction(
      functionName: 'verifyPasswordResetCode',
      body: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
      },
    );
    final token = data['resetToken']?.toString().trim() ?? '';
    if (token.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-reset-session');
    }
    return token;
  }

  Future<void> completePasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    await _postPasswordResetFunction(
      functionName: 'completePasswordReset',
      body: {
        'email': email.trim().toLowerCase(),
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
    );
  }

  Future<Map<String, dynamic>> _postPasswordResetFunction({
    required String functionName,
    required Map<String, dynamic> body,
  }) async {
    final functionUrl = Uri.parse(
      'https://us-central1-${DefaultFirebaseOptions.currentPlatform.projectId}'
      '.cloudfunctions.net/$functionName',
    );
    final response = await http.post(
      functionUrl,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    Object? decoded;
    try {
      decoded = response.body.trim().isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    final data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    throw FirebaseAuthException(
      code: data['error']?.toString() ?? 'password-reset-failed',
    );
  }

  Future<void> _sendCustomPasswordEmail({
    required String email,
    required String churchName,
    required String mode,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final functionUrl = Uri.parse(
      'https://us-central1-${DefaultFirebaseOptions.currentPlatform.projectId}.cloudfunctions.net/sendPasswordResetSmtpEmail',
    );

    final response = await http.post(
      functionUrl,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': normalizedEmail,
        'churchName': churchName.trim(),
        'mode': mode,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw FirebaseAuthException(
      code: 'reset-email-failed',
      message: defaultChurchTextContents['auth.reset_email_failed'],
    );
  }

  /// Deletes the signed-in person's account entirely (§6 Phase 7): every
  /// membership across every church (and that membership's own progress
  /// and group rows), the identity doc and its subcollections, Storage
  /// blobs, then the Auth user — done server-side by the `deleteAccount`
  /// callable, since a client can't safely enumerate every membership
  /// across churches it isn't itself scoped to, nor delete its own Auth
  /// user's cross-church footprint atomically.
  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: defaultChurchTextContents['auth.no_signed_in_user'],
      );
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: defaultChurchTextContents['auth.email_verification_failed'],
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    // Refreshes the ID token's auth_time — the callable checks it's recent
    // before doing anything irreversible.
    await user.reauthenticateWithCredential(credential);

    await _functions.httpsCallable('deleteAccount').call<void>();
  }

  /// Leaves one church (§6 Phase 7): deletes the membership and group rows
  /// there only. Identity, favorites, reading plans, Church Tree progress
  /// and streak all live on `users/{uid}` and are untouched.
  Future<void> leaveChurch({required String churchId}) async {
    await _functions.httpsCallable('leaveChurch').call<void>({
      'churchId': churchId,
    });
  }

  /// Signup email-OTP (§5.5 addendum) — sends a 6-digit code to the
  /// caller's own Firebase Auth email. Callable, not onRequest like
  /// password reset, since the caller is already signed in by this point.
  Future<void> requestSignupEmailVerificationCode({
    String churchName = '',
  }) async {
    await _functions
        .httpsCallable('requestSignupEmailVerificationCode')
        .call<void>({
      if (churchName.trim().isNotEmpty) 'churchName': churchName.trim(),
    });
  }

  Future<void> verifySignupEmailVerificationCode({required String code}) async {
    await _functions
        .httpsCallable('verifySignupEmailVerificationCode')
        .call<void>({'code': code.trim()});
  }

  Future<void> requestAccess(
      {required String name,
      required String phone,
      required String contact,
      required String location,
      required String address,
      required String gender,
      required String category,
      required String familyId,
      required DateTime dob,
      required String authToken,
      required String churchId,
      String maritalStatus = '',
      DateTime? weddingDay,
      int financialStabilityRating = 0,
      bool financialSupportRequired = false,
      String educationalQualification = '',
      List<String> talentsAndGifts = const [],
      List<String> churchGroupIds = const [],
      bool solemnizedBaptism = false,
      DateTime? baptismDate,
      String baptismCertificateNumber = '',
      String baptismChurchName = '',
      String baptismPastorName = '',
      String marriageSolemnizationChurchType = '',
      String marriageSolemnizationChurchName = '',
      String membershipCurrentStatus = '',
      String membershipNotes = '',
      String additionalNotes = '',
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
        message: defaultChurchTextContents['auth.no_signed_in_user'],
      );
    }

    final membersRef = FirestorePaths.churchMembers(_firestore, churchId);
    final generatedDocId =
        createChurchMemberWithoutAuth ? membersRef.doc().id : null;
    final uid = targetUid ?? generatedDocId ?? currentUser!.uid;
    final email = createChurchMemberWithoutAuth
        ? (targetEmail ?? '').trim().toLowerCase()
        : (targetEmail ?? currentUser?.email ?? '').trim().toLowerCase();
    final docRef = membersRef.doc(uid);
    // Unlinked (admin-created, no auth) members have no identity doc — the
    // fields below are THEIR authoritative profile, stored as display* on
    // the membership itself (§9.2/§9.3). A linked signup gets a real
    // identity doc too, since this screen still doubles as first-time
    // signup until the dedicated profile step exists (KT Files/
    // architecture/user-church-decoupling-migration.md §5.5).
    final linkedUid = createChurchMemberWithoutAuth ? null : uid;

    await docRef.set({
      'uid': linkedUid ?? '',
      'linkedUid': linkedUid,
      'category': category.trim(),
      'familyId': familyId.trim(),
      'churchGroupIds': churchGroupIds
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      'financialStabilityRating': financialStabilityRating,
      'financialSupportRequired': financialSupportRequired,
      'solemnizedBaptism': solemnizedBaptism,
      'baptismDate': solemnizedBaptism && baptismDate != null
          ? Timestamp.fromDate(baptismDate)
          : null,
      'baptismCertificateNumber':
          solemnizedBaptism ? baptismCertificateNumber.trim() : '',
      'baptismChurchName': solemnizedBaptism ? baptismChurchName.trim() : '',
      'baptismPastorName': solemnizedBaptism ? baptismPastorName.trim() : '',
      'marriageSolemnizationChurchType':
          maritalStatus.trim().toLowerCase() == 'married'
              ? marriageSolemnizationChurchType.trim()
              : '',
      'marriageSolemnizationChurchName':
          maritalStatus.trim().toLowerCase() == 'married'
              ? marriageSolemnizationChurchName.trim()
              : '',
      'membershipCurrentStatus': membershipCurrentStatus.trim(),
      'membershipNotes': membershipNotes.trim(),
      'additionalNotes': additionalNotes.trim(),
      'approved': approved,
      'notifyOnApproval': false,
      'joinedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
      'displayName': name.trim(),
      'displayEmail': email,
      'displayPhone': phone.trim(),
      'displayDob': Timestamp.fromDate(dob),
      'displayGender': gender.trim(),
      'displayWeddingDay':
          weddingDay != null ? Timestamp.fromDate(weddingDay) : null,
      'displayMaritalStatus': maritalStatus.trim(),
      'displayEducationalQualification': educationalQualification.trim(),
      'displayTalentsAndGifts': talentsAndGifts
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      'displayLocation': location.trim(),
      'displayAddress': address.trim(),
      'identitySyncedAt': FieldValue.serverTimestamp(),
    });

    if (linkedUid != null) {
      final identityDocRef = FirestorePaths.userDoc(_firestore, linkedUid);
      final identitySnapshot = await identityDocRef.get();
      await identityDocRef.set({
        'name': name.trim(),
        'email': email,
        'phone': phone.trim(),
        'dob': Timestamp.fromDate(dob),
        'gender': gender.trim(),
        'location': location.trim(),
        'address': address.trim(),
        'maritalStatus': maritalStatus.trim(),
        'weddingDay':
            weddingDay != null ? Timestamp.fromDate(weddingDay) : null,
        'educationalQualification': educationalQualification.trim(),
        'talentsAndGifts': talentsAndGifts
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
        'profileComplete': true,
        'schemaVersion': 1,
        if (!identitySnapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _syncChurchGroupMemberships(
      churchId: churchId,
      userId: uid,
      name: name.trim(),
      email: email,
      phone: phone.trim(),
      category: category.trim(),
      churchGroupIds: churchGroupIds,
    );

    if (category.trim() == 'family') {
      await FirestorePaths.churchFamilies(_firestore, churchId)
          .doc(familyId.trim())
          .set({
        'familyId': familyId.trim(),
        'familyHead': name.trim(),
        'familyHeadUid': uid,
        'category': category.trim(),
        'churchId': churchId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Opts a pending request into the approval push+email
  /// (`notifyMemberOnApproval` in functions) — tapped from
  /// `RequestPendingScreen`. A no-op field on any other membership row.
  Future<void> setNotifyOnApproval({
    required String churchId,
    required String uid,
    required bool value,
  }) {
    return FirestorePaths.churchMemberDoc(_firestore, churchId, uid).update({
      'notifyOnApproval': value,
    });
  }

  Future<List<String>> getFamilyIds(String churchId) async {
    final snapshot = await FirestorePaths.churchFamilies(_firestore, churchId)
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
    return FirestorePaths.churchMemberDoc(_firestore, churchId, uid).get();
  }

  Future<void> _syncChurchGroupMemberships({
    required String churchId,
    required String userId,
    required String name,
    required String email,
    required String phone,
    required String category,
    required List<String> churchGroupIds,
  }) async {
    final batch = _firestore.batch();

    for (final group in churchGroupDefinitions) {
      final groupDoc = FirestorePaths.churchGroupDoc(
        _firestore,
        churchId,
        group.id,
      );
      final memberDoc =
          FirestorePaths.churchGroupMembers(_firestore, churchId, group.id)
              .doc(userId);

      batch.set(
          groupDoc,
          {
            'id': group.id,
            'label': group.label,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      if (churchGroupIds.contains(group.id)) {
        batch.set(
            memberDoc,
            {
              'uid': userId,
              'email': email.trim().toLowerCase(),
              'name': name,
              'phone': phone,
              'category': category,
              'groupId': group.id,
              'groupLabel': group.label,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      } else {
        batch.delete(memberDoc);
      }
    }

    await batch.commit();
  }
}
