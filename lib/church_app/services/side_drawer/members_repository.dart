import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/helpers/church_group_definitions.dart';
import 'package:flutter_application/church_app/models/church_group_member_model.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/models/user_identity_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class MembersRepository extends ChurchScopedRepository {
  MembersRepository({
    required super.firestore,
    required super.churchId,
  });

  CollectionReference<ChurchMembership> collectionRef() {
    return FirestorePaths.churchMembers(firestore, churchId)
        .withConverter<ChurchMembership>(
      fromFirestore: (snap, _) => ChurchMembership.fromFirestore(
        snap.id,
        churchId,
        snap.data()!,
      ),
      toFirestore: (member, _) => member.toMap(),
    );
  }

  Future<List<ChurchMembership>> getMembersOnce() async {
    final snapshot = await collectionRef().get();
    final members = snapshot.docs.map((doc) => doc.data()).toList()
      ..sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return members;
  }

  /// Server-side search/pagination — must stay pointed at the display*
  /// cache, not identity fields: ordering, prefix matching and cursor
  /// pagination can't join across documents (§9.2).
  Future<MemberSearchPage> fetchMembersPage({
    String query = '',
    int limit = 25,
    DocumentSnapshot<ChurchMembership>? startAfter,
  }) async {
    final normalizedQuery = query.trim();
    final searchField = _searchFieldForQuery(normalizedQuery);

    Query<ChurchMembership> queryRef =
        collectionRef().orderBy(searchField).limit(limit);

    if (normalizedQuery.isNotEmpty) {
      queryRef =
          queryRef.startAt([normalizedQuery]).endAt(['$normalizedQuery']);
    }

    if (startAfter != null) {
      queryRef = queryRef.startAfterDocument(startAfter);
    }

    final snapshot = await queryRef.get();
    return MemberSearchPage(
      members: snapshot.docs.map((doc) => doc.data()).toList(growable: false),
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<ChurchMembership?> getMemberById(String docId) async {
    final snapshot = await collectionRef().doc(docId).get();
    return snapshot.data();
  }

  Stream<ChurchMembership?> watchMemberById(String docId) {
    return collectionRef().doc(docId).snapshots().map((snapshot) {
      return snapshot.data();
    });
  }

  Future<List<ChurchMembership>> getMembersByFamilyIds(
      List<String> familyIds) async {
    final normalizedIds = familyIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedIds.isEmpty) {
      return const <ChurchMembership>[];
    }

    if (normalizedIds.length == 1) {
      final snapshot = await collectionRef()
          .where('familyId', isEqualTo: normalizedIds.first)
          .get();

      final members = snapshot.docs.map((doc) => doc.data()).toList()
        ..sort((a, b) => a.displayName
            .toLowerCase()
            .compareTo(b.displayName.toLowerCase()));
      return members;
    }

    final docs = <QueryDocumentSnapshot<ChurchMembership>>[];
    for (var i = 0; i < normalizedIds.length; i += 10) {
      final chunk = normalizedIds.skip(i).take(10).toList(growable: false);
      final chunkSnapshot =
          await collectionRef().where('familyId', whereIn: chunk).get();
      docs.addAll(chunkSnapshot.docs);
    }

    final members = docs.map((doc) => doc.data()).toList()
      ..sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return members;
  }

  Stream<List<ChurchGroupMember>> watchGroupMembers(String groupId) {
    return FirestorePaths.churchGroupMembers(firestore, churchId, groupId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChurchGroupMember.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> approveMember(String docId, bool value) {
    return collectionRef().doc(docId).update({
      'approved': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMemberCategory(
    String docId, {
    required String category,
    required String familyId,
  }) {
    return collectionRef().doc(docId).update({
      'category': category.trim().toLowerCase(),
      'familyId': familyId.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMemberChurchGroups(
    String docId, {
    required List<String> churchGroupIds,
  }) async {
    final normalizedGroupIds = churchGroupIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

    await collectionRef().doc(docId).update({
      'churchGroupIds': normalizedGroupIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final member = (await collectionRef().doc(docId).get()).data();
    if (member == null) {
      throw StateError('Member not found.');
    }

    await _syncChurchGroupMemberships(
      docId: docId,
      name: member.displayName.trim(),
      email: member.displayEmail.trim().toLowerCase(),
      phone: member.displayPhone.trim(),
      category: member.category.trim(),
      churchGroupIds: normalizedGroupIds,
      profilePhotoUrl: member.displayPhotoUrl,
    );
  }

  /// Admin edit form. Identity-shaped fields (name, phone, location,
  /// address, gender, dob, maritalStatus, weddingDay,
  /// educationalQualification, talentsAndGifts) only actually persist for an
  /// **unlinked** member — that's this row's own authoritative profile
  /// (§9.2/§9.3). For a linked member they're read-only display of what the
  /// person set themselves; rules reject a client attempt to change them
  /// there (the Phase 6 fan-out is the only writer once linked), so passing
  /// the member's own current values through here is always safe.
  Future<void> updateMemberDetails(
    String docId, {
    required String name,
    required String phone,
    required String location,
    required String address,
    required String gender,
    required String category,
    required String familyId,
    required DateTime dob,
    required String maritalStatus,
    required DateTime? weddingDay,
    required int financialStabilityRating,
    required bool financialSupportRequired,
    required String educationalQualification,
    required List<String> talentsAndGifts,
    required List<String> churchGroupIds,
    required bool solemnizedBaptism,
    required DateTime? baptismDate,
    required String baptismCertificateNumber,
    required String baptismChurchName,
    required String baptismPastorName,
    required String marriageSolemnizationChurchType,
    required String marriageSolemnizationChurchName,
    required String membershipCurrentStatus,
    required String membershipNotes,
    required String additionalNotes,
    String? familyLabel,
  }) async {
    await collectionRef().doc(docId).update({
      'displayName': name.trim(),
      'displayPhone': phone.trim(),
      'displayGender': gender.trim(),
      'category': category.trim(),
      'familyId': familyId.trim(),
      'displayDob': Timestamp.fromDate(dob),
      'displayMaritalStatus': maritalStatus.trim(),
      'displayWeddingDay':
          weddingDay != null ? Timestamp.fromDate(weddingDay) : null,
      'financialStabilityRating': financialStabilityRating,
      'financialSupportRequired': financialSupportRequired,
      'displayEducationalQualification': educationalQualification.trim(),
      'displayTalentsAndGifts': talentsAndGifts
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
      'displayLocation': location.trim(),
      'displayAddress': address.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final updatedMember = (await collectionRef().doc(docId).get()).data();
    await _syncChurchGroupMemberships(
      docId: docId,
      name: name.trim(),
      email: updatedMember?.displayEmail ?? '',
      phone: phone.trim(),
      category: category.trim(),
      churchGroupIds: churchGroupIds,
      profilePhotoUrl: updatedMember?.displayPhotoUrl ?? '',
    );

    if (category.trim() == 'family') {
      await FirestorePaths.churchFamilies(firestore, churchId)
          .doc(familyId.trim())
          .set({
        'familyId': familyId.trim(),
        'familyHead': name.trim(),
        'familyHeadUid': docId,
        'category': category.trim(),
        'churchId': churchId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Links an admin-created (no-auth, random-id) member to a real account —
  /// re-keys the membership doc to the new uid and, if no identity doc
  /// exists yet, creates one seeded from the membership's own (previously
  /// authoritative) display* fields (§9.3, §9.7).
  Future<void> attachFirebaseAuthToMember(
    String existingDocId, {
    required String newUid,
    required String email,
  }) async {
    final existingDoc =
        await FirestorePaths.churchMemberDoc(firestore, churchId, existingDocId)
            .get();
    if (!existingDoc.exists) {
      throw StateError('Member not found.');
    }

    final existingData = existingDoc.data()!;
    final newDoc = FirestorePaths.churchMemberDoc(firestore, churchId, newUid);
    final batch = firestore.batch();

    final displayName = (existingData['displayName'] ?? '').toString();
    final displayPhone = (existingData['displayPhone'] ?? '').toString();
    final displayPhotoUrl = (existingData['displayPhotoUrl'] ?? '').toString();
    final displayGender = (existingData['displayGender'] ?? '').toString();
    final displayDob = existingData['displayDob'];

    final identityDoc = FirestorePaths.userDoc(firestore, newUid);
    final identitySnapshot = await identityDoc.get();
    if (!identitySnapshot.exists) {
      batch.set(identityDoc, UserIdentity(
        uid: newUid,
        name: displayName,
        email: email.trim().toLowerCase(),
        phone: displayPhone,
        profilePhotoUrl: displayPhotoUrl,
        gender: displayGender,
        dob: displayDob is Timestamp ? displayDob.toDate() : null,
      ).toMap());
    }

    batch.set(newDoc, {
      ...existingData,
      'uid': newUid,
      'linkedUid': newUid,
      'displayEmail': email.trim().toLowerCase(),
      'identitySyncedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final churchGroupIds =
        (existingData['churchGroupIds'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();
    final category = (existingData['category'] ?? '').toString();

    if (existingDocId != newUid) {
      batch.delete(existingDoc.reference);
    }

    for (final group in churchGroupDefinitions) {
      final groupDoc =
          FirestorePaths.churchGroupDoc(firestore, churchId, group.id);
      batch.set(
          groupDoc,
          {
            'id': group.id,
            'label': group.label,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      final oldGroupMemberDoc =
          FirestorePaths.churchGroupMembers(firestore, churchId, group.id)
              .doc(existingDocId);
      final newGroupMemberDoc =
          FirestorePaths.churchGroupMembers(firestore, churchId, group.id)
              .doc(newUid);

      if (churchGroupIds.contains(group.id)) {
        batch.set(
            newGroupMemberDoc,
            {
              'uid': newUid,
              'email': email.trim().toLowerCase(),
              'name': displayName,
              'phone': displayPhone,
              'category': category,
              'groupId': group.id,
              'groupLabel': group.label,
              'profilePhotoUrl': displayPhotoUrl,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
        if (existingDocId != newUid) {
          batch.delete(oldGroupMemberDoc);
        }
      } else {
        batch.delete(newGroupMemberDoc);
        if (existingDocId != newUid) {
          batch.delete(oldGroupMemberDoc);
        }
      }
    }

    await batch.commit();
  }

  Future<void> deleteMember(String docId) {
    return _deleteChurchMemberData(docId);
  }

  Future<void> _deleteChurchMemberData(String docId) async {
    final memberDoc =
        await FirestorePaths.churchMemberDoc(firestore, churchId, docId).get();
    final memberData = memberDoc.data();
    final familyId = (memberData?['familyId'] ?? '').toString().trim();

    if (familyId.isNotEmpty) {
      final familyDoc = await FirestorePaths.churchFamilies(firestore, churchId)
          .doc(familyId)
          .get();
      final familyHeadUid =
          (familyDoc.data()?['familyHeadUid'] ?? '').toString().trim();
      if (familyHeadUid == docId) {
        final familyMembers =
            await collectionRef().where('familyId', isEqualTo: familyId).get();
        final remainingMembers = familyMembers.docs
            .map((doc) => doc.data())
            .where((member) => member.docId != docId)
            .toList()
          ..sort((a, b) => a.displayName
              .toLowerCase()
              .compareTo(b.displayName.toLowerCase()));

        if (remainingMembers.isEmpty) {
          await familyDoc.reference.delete().catchError((_) {});
        } else {
          final newFamilyHead = remainingMembers.first;
          await familyDoc.reference.set({
            'familyId': familyId,
            'familyHead': newFamilyHead.displayName.trim(),
            'familyHeadUid': newFamilyHead.docId,
            'category': newFamilyHead.category.trim(),
            'churchId': churchId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    }

    for (final group in churchGroupDefinitions) {
      await FirestorePaths.churchGroupMembers(firestore, churchId, group.id)
          .doc(docId)
          .delete()
          .catchError((_) {});
    }
    await FirestorePaths.churchMemberDoc(firestore, churchId, docId).delete();
  }

  Future<void> _syncChurchGroupMemberships({
    required String docId,
    required String name,
    required String email,
    required String phone,
    required String category,
    required List<String> churchGroupIds,
    required String profilePhotoUrl,
  }) async {
    final batch = firestore.batch();

    for (final group in churchGroupDefinitions) {
      final groupDoc =
          FirestorePaths.churchGroupDoc(firestore, churchId, group.id);
      final memberDoc =
          FirestorePaths.churchGroupMembers(firestore, churchId, group.id)
              .doc(docId);

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
              'uid': docId,
              'email': email.trim().toLowerCase(),
              'name': name,
              'phone': phone,
              'category': category,
              'groupId': group.id,
              'groupLabel': group.label,
              'profilePhotoUrl': profilePhotoUrl,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      } else {
        batch.delete(memberDoc);
      }
    }

    await batch.commit();
  }

  String _searchFieldForQuery(String query) {
    if (query.contains('@')) return 'displayEmail';
    if (RegExp(r'^[\d+\-\s()]+$').hasMatch(query) && query.length >= 3) {
      return 'displayPhone';
    }
    return 'displayName';
  }
}

class MemberSearchPage {
  const MemberSearchPage({
    required this.members,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<ChurchMembership> members;
  final DocumentSnapshot<ChurchMembership>? lastDocument;
  final bool hasMore;
}
