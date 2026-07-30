import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class PrayerRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final String churchId;

  PrayerRepository({
    required this.firestore,
    required this.auth,
    required this.churchId,
  });

  String? get _uid => auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> collectionRef() {
    return FirestorePaths.churchPrayerRequests(firestore, churchId);
  }

  CollectionReference<Map<String, dynamic>> globalCollectionRef() {
    return FirestorePaths.globalPrayerCollection(firestore);
  }

  String _globalPrayerId(String prayerId) => '${churchId}_$prayerId';

  Future<void> _ensureCurrentUserIsAdmin() async {
    final email = auth.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      throw Exception('Only church admins can manage global prayer requests');
    }

    final configSnapshot =
        await FirestorePaths.churchAppConfig(firestore, churchId).get();
    final admins = (configSnapshot.data()?['admins'] as Iterable? ?? const [])
        .map((value) => value.toString().trim().toLowerCase());
    if (!admins.contains(email)) {
      throw Exception('Only church admins can manage global prayer requests');
    }
  }

  Future<DocumentReference<Map<String, dynamic>>> _validatedPrayerDoc(
    String prayerId,
  ) async {
    final prayerDoc = collectionRef().doc(prayerId);
    final snapshot = await prayerDoc.get();

    if (!snapshot.exists) {
      throw Exception("Prayer request not found for the selected church");
    }

    return prayerDoc;
  }

  /// ADD PRAYER
  Future<void> addPrayer({
    required String title,
    required String description,
    required bool isAnonymous,
    required bool visibleToChurchMembers,
    required DateTime expiryDate,
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final maxDate = today.add(const Duration(days: 30));

    if (selectedDate.isBefore(today) || selectedDate.isAfter(maxDate)) {
      throw Exception("Expiry date must be within 30 days");
    }

    await collectionRef().add({
      'churchId': churchId,
      'userId': user.uid,
      'email': user.email,
      'title': title.trim(),
      'description': description.trim(),
      'isAnonymous': isAnonymous,
      'visibleToChurchMembers': visibleToChurchMembers,
      'isGlobal': false,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'expiryDate': Timestamp.fromDate(selectedDate),
    });
  }

  /// UPDATE PRAYER
  Future<void> updatePrayer({
    required String prayerId,
    required String title,
    required String description,
    required bool isAnonymous,
    required bool visibleToChurchMembers,
    required DateTime expiryDate,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final maxDate = today.add(const Duration(days: 30));

    if (selectedDate.isBefore(today) || selectedDate.isAfter(maxDate)) {
      throw Exception("Expiry date must be within 30 days");
    }

    final prayerDoc = await _validatedPrayerDoc(prayerId);

    final existingSnapshot = await prayerDoc.get();
    final existing = existingSnapshot.data() ?? const <String, dynamic>{};
    final updates = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'isAnonymous': isAnonymous,
      'visibleToChurchMembers': visibleToChurchMembers,
      'expiryDate': Timestamp.fromDate(selectedDate),
      'updatedAt': Timestamp.fromDate(now),
    };

    final batch = firestore.batch()..update(prayerDoc, updates);
    if (existing['isGlobal'] == true) {
      batch.set(
        globalCollectionRef().doc(_globalPrayerId(prayerId)),
        {
          ...updates,
          'userId': isAnonymous ? '' : existing['userId'] ?? '',
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// WATCH MY PRAYERS
  Stream<List<PrayerRequest>> watchMyPrayers() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    return collectionRef()
        .where('userId', isEqualTo: uid)
        .where(
          'expiryDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
        )
        .orderBy('expiryDate')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(PrayerRequest.fromDoc).toList(),
        );
  }

  /// WATCH ALL ACTIVE PRAYERS
  Stream<List<PrayerRequest>> getAllPrayers() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    return collectionRef()
        .where(
          'expiryDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
        )
        .orderBy('expiryDate')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(PrayerRequest.fromDoc).toList(),
        );
  }

  Stream<List<PrayerRequest>> watchPrayersVisibleToChurchMembers() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    return collectionRef()
        .where('visibleToChurchMembers', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final prayers = snapshot.docs
          .map(PrayerRequest.fromDoc)
          .where((prayer) => !prayer.expiryDate.isBefore(startOfToday))
          .toList(growable: false)
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      return prayers;
    });
  }

  Stream<List<PrayerRequest>> watchGlobalPrayers() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    return globalCollectionRef()
        .where(
          'expiryDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
        )
        .orderBy('expiryDate')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(PrayerRequest.fromDoc).toList(growable: false),
        );
  }

  Future<void> setPrayerGlobal({
    required String prayerId,
    required bool isGlobal,
  }) async {
    await _ensureCurrentUserIsAdmin();
    final prayerDoc = await _validatedPrayerDoc(prayerId);
    final globalDoc = globalCollectionRef().doc(_globalPrayerId(prayerId));

    if (!isGlobal) {
      final batch = firestore.batch()
        ..update(prayerDoc, {
          'isGlobal': false,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        ..delete(globalDoc);
      await batch.commit();
      return;
    }

    final prayerSnapshot = await prayerDoc.get();
    final prayer = prayerSnapshot.data();
    if (prayer == null) {
      throw Exception('Prayer request not found');
    }

    final churchSnapshot =
        await FirestorePaths.churchDoc(firestore, churchId).get();
    final churchData = churchSnapshot.data() as Map<String, dynamic>?;
    final churchName = (churchData?['name'] as String? ?? '').trim();
    final now = FieldValue.serverTimestamp();

    final batch = firestore.batch()
      ..update(prayerDoc, {
        'isGlobal': true,
        'updatedAt': now,
      })
      ..set(globalDoc, {
        'title': prayer['title'] ?? '',
        'description': prayer['description'] ?? '',
        'userId': prayer['isAnonymous'] == true ? '' : prayer['userId'] ?? '',
        'isAnonymous': prayer['isAnonymous'] == true,
        'visibleToChurchMembers': prayer['visibleToChurchMembers'] == true,
        'expiryDate': prayer['expiryDate'],
        'createdAt': prayer['createdAt'] ?? now,
        'updatedAt': now,
        'isGlobal': true,
        'sourceChurchId': churchId,
        'sourcePrayerId': prayerId,
        'sourceChurchName': churchName,
      });
    await batch.commit();
  }

  Future<List<PrayerRequest>> getAllPrayersOnce() async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    final snapshot = await collectionRef()
        .where(
          'expiryDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
        )
        .orderBy('expiryDate')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map(PrayerRequest.fromDoc).toList(growable: false);
  }

  Future<void> deletePrayer(String prayerId) async {
    final prayerDoc = await _validatedPrayerDoc(prayerId);
    final batch = firestore.batch()
      ..delete(prayerDoc)
      ..delete(globalCollectionRef().doc(_globalPrayerId(prayerId)));
    await batch.commit();
  }
}
