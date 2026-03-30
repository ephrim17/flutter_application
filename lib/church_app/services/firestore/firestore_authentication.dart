import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application/church_app/helpers/church_group_definitions.dart';
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
          message: 'Unable to create the member account.',
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
    await _sendCustomPasswordEmail(
      email: email,
      churchName: churchName,
      mode: 'reset',
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
      message: 'Unable to send the reset email right now.',
    );
  }

  Future<void> deleteAccount({
    required String churchId,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed in user found.',
      );
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Unable to verify this account email.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);

    final userId = user.uid;
    await _deleteFirestoreUserData(
      churchId: churchId,
      uid: userId,
    );

    await user.delete();
  }

  Future<void> _deleteFirestoreUserData({
    required String churchId,
    required String uid,
  }) async {
    final batch = _firestore.batch();

    final readingPlans =
        await FirestorePaths.churchUserReadingPlans(_firestore, churchId, uid)
            .get();

    for (final doc in readingPlans.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(FirestorePaths.churchUserDoc(_firestore, churchId, uid));

    final globalUserDoc = await FirestorePaths.userDoc(_firestore, uid).get();
    if (globalUserDoc.exists) {
      batch.delete(globalUserDoc.reference);
    }

    await batch.commit();
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
        message: 'No signed in user found.',
      );
    }

    final usersRef = FirestorePaths.churchUsers(_firestore, churchId);
    final generatedDocId =
        createChurchMemberWithoutAuth ? usersRef.doc().id : null;
    final uid = targetUid ?? generatedDocId ?? currentUser!.uid;
    final email = createChurchMemberWithoutAuth
        ? (targetEmail ?? '').trim().toLowerCase()
        : (targetEmail ?? currentUser?.email ?? '').trim().toLowerCase();
    final docRef = usersRef.doc(uid);

    await docRef.set({
      'uid': uid,
      'name': name.trim(),
      'email': email,
      'phone': phone.trim(),
      'contact': contact.trim(),
      'location': location.trim(),
      'address': address.trim(),
      'gender': gender.trim(),
      'category': category.trim(),
      'familyId': familyId.trim(),
      'dob': Timestamp.fromDate(dob),
      'maritalStatus': maritalStatus.trim(),
      'weddingDay': weddingDay != null ? Timestamp.fromDate(weddingDay) : null,
      'financialStabilityRating': financialStabilityRating,
      'financialSupportRequired': financialSupportRequired,
      'educationalQualification': educationalQualification.trim(),
      'talentsAndGifts': talentsAndGifts
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      'churchGroupIds': churchGroupIds
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
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
      'authToken': authToken,
      'createdAt': FieldValue.serverTimestamp(),
    });

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
    return FirestorePaths.churchUserDoc(_firestore, churchId, uid).get();
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
