import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/helpers/church_group_definitions.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/church_group_member_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class MembersRepository extends ChurchScopedRepository {
  MembersRepository({
    required super.firestore,
    required super.churchId,
  });

  CollectionReference<AppUser> collectionRef() {
    return FirestorePaths.churchUsers(firestore, churchId)
        .withConverter<AppUser>(
      fromFirestore: (snap, _) => AppUser.fromFirestore(
        snap.id, // 👈 document ID
        snap.data()!,
      ),
      toFirestore: (user, _) => user.toMap(),
    );
  }

  Stream<List<AppUser>> getMembers() {
    return collectionRef().snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
        );
  }

  Future<List<AppUser>> getMembersOnce() async {
    final snapshot = await collectionRef().get();
    final members = snapshot.docs.map((doc) => doc.data()).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return members;
  }

  Future<AppUser?> getMemberById(String userId) async {
    final snapshot = await collectionRef().doc(userId).get();
    return snapshot.data();
  }

  Future<List<AppUser>> getMembersByFamilyIds(List<String> familyIds) async {
    final normalizedIds = familyIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedIds.isEmpty) {
      return const <AppUser>[];
    }

    if (normalizedIds.length == 1) {
      final snapshot = await collectionRef()
          .where('familyId', isEqualTo: normalizedIds.first)
          .get();

      final members = snapshot.docs.map((doc) => doc.data()).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return members;
    }

    final docs = <QueryDocumentSnapshot<AppUser>>[];
    for (var i = 0; i < normalizedIds.length; i += 10) {
      final chunk = normalizedIds.skip(i).take(10).toList(growable: false);
      final chunkSnapshot =
          await collectionRef().where('familyId', whereIn: chunk).get();
      docs.addAll(chunkSnapshot.docs);
    }

    final members = docs.map((doc) => doc.data()).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  Future<void> approveMember(String userId, bool value) {
    return collectionRef().doc(userId).update({
      'approved': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMemberCategory(
    String userId, {
    required String category,
    required String familyId,
  }) {
    return collectionRef().doc(userId).update({
      'category': category.trim().toLowerCase(),
      'familyId': familyId.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMemberChurchGroups(
    String userId, {
    required List<String> churchGroupIds,
  }) async {
    final normalizedGroupIds = churchGroupIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

    await collectionRef().doc(userId).update({
      'churchGroupIds': normalizedGroupIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final member = (await collectionRef().doc(userId).get()).data();
    if (member == null) {
      throw StateError('Member not found.');
    }

    await _syncChurchGroupMemberships(
      userId: userId,
      name: member.name.trim(),
      email: member.email.trim().toLowerCase(),
      phone: member.phone.trim(),
      category: member.category.trim(),
      churchGroupIds: normalizedGroupIds,
    );
  }

  Future<void> updateMemberDetails(
    String userId, {
    required String name,
    required String phone,
    required String contact,
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
    await collectionRef().doc(userId).update({
      'name': name.trim(),
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
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _syncChurchGroupMemberships(
      userId: userId,
      name: name.trim(),
      email: (await collectionRef().doc(userId).get()).data()?.email ?? '',
      phone: phone.trim(),
      category: category.trim(),
      churchGroupIds: churchGroupIds,
    );

    if (category.trim() == 'family') {
      await FirestorePaths.churchFamilies(firestore, churchId)
          .doc(familyId.trim())
          .set({
        'familyId': familyId.trim(),
        'familyHead': name.trim(),
        'familyHeadUid': userId,
        'category': category.trim(),
        'churchId': churchId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> attachFirebaseAuthToMember(
    String existingUserId, {
    required String newUid,
    required String email,
  }) async {
    final existingDoc =
        await FirestorePaths.churchUserDoc(firestore, churchId, existingUserId)
            .get();
    if (!existingDoc.exists) {
      throw StateError('Member not found.');
    }

    final existingData = existingDoc.data() as Map<String, dynamic>;
    final newDoc = FirestorePaths.churchUserDoc(firestore, churchId, newUid);
    final batch = firestore.batch();

    batch.set(newDoc, {
      ...existingData,
      'uid': newUid,
      'email': email.trim().toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final churchGroupIds =
        (existingData['churchGroupIds'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();
    final name = (existingData['name'] ?? '').toString();
    final phone = (existingData['phone'] ?? '').toString();
    final category = (existingData['category'] ?? '').toString();

    if (existingUserId != newUid) {
      final readingPlans = await FirestorePaths.churchUserReadingPlans(
              firestore, churchId, existingUserId)
          .get();

      for (final doc in readingPlans.docs) {
        batch.set(
          FirestorePaths.churchUserReadingPlans(firestore, churchId, newUid)
              .doc(doc.id),
          doc.data(),
        );
        batch.delete(doc.reference);
      }

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
              .doc(existingUserId);
      final newGroupMemberDoc =
          FirestorePaths.churchGroupMembers(firestore, churchId, group.id)
              .doc(newUid);

      if (churchGroupIds.contains(group.id)) {
        batch.set(
            newGroupMemberDoc,
            {
              'uid': newUid,
              'email': email.trim().toLowerCase(),
              'name': name,
              'phone': phone,
              'category': category,
              'groupId': group.id,
              'groupLabel': group.label,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
        if (existingUserId != newUid) {
          batch.delete(oldGroupMemberDoc);
        }
      } else {
        batch.delete(newGroupMemberDoc);
        if (existingUserId != newUid) {
          batch.delete(oldGroupMemberDoc);
        }
      }
    }

    await batch.commit();
  }

  Future<void> deleteMember(String userId) {
    return _deleteChurchUserData(userId);
  }

  Future<void> _deleteChurchUserData(String userId) async {
    final userDoc =
        await FirestorePaths.churchUserDoc(firestore, churchId, userId).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final familyId = (userData?['familyId'] ?? '').toString().trim();

    if (familyId.isNotEmpty) {
      final familyDoc = await FirestorePaths.churchFamilies(firestore, churchId)
          .doc(familyId)
          .get();
      final familyHeadUid =
          (familyDoc.data()?['familyHeadUid'] ?? '').toString().trim();
      if (familyHeadUid == userId) {
        final familyMembers =
            await collectionRef().where('familyId', isEqualTo: familyId).get();
        final remainingMembers = familyMembers.docs
            .map((doc) => doc.data())
            .where((member) => member.uid != userId)
            .toList()
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (remainingMembers.isEmpty) {
          await familyDoc.reference.delete().catchError((_) {});
        } else {
          final newFamilyHead = remainingMembers.first;
          await familyDoc.reference.set({
            'familyId': familyId,
            'familyHead': newFamilyHead.name.trim(),
            'familyHeadUid': newFamilyHead.uid,
            'category': newFamilyHead.category.trim(),
            'churchId': churchId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    }

    for (final group in churchGroupDefinitions) {
      await FirestorePaths.churchGroupMembers(firestore, churchId, group.id)
          .doc(userId)
          .delete()
          .catchError((_) {});
    }
    await _deleteCollection(
      FirestorePaths.churchUserReadingPlans(firestore, churchId, userId),
    );
    await FirestorePaths.churchUserDoc(firestore, churchId, userId).delete();
  }

  Future<void> _syncChurchGroupMemberships({
    required String userId,
    required String name,
    required String email,
    required String phone,
    required String category,
    required List<String> churchGroupIds,
  }) async {
    final batch = firestore.batch();

    for (final group in churchGroupDefinitions) {
      final groupDoc =
          FirestorePaths.churchGroupDoc(firestore, churchId, group.id);
      final memberDoc =
          FirestorePaths.churchGroupMembers(firestore, churchId, group.id)
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

  Future<void> _deleteCollection(CollectionReference collectionRef) async {
    while (true) {
      final snapshot = await collectionRef.limit(50).get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
  }
}
