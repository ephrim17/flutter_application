import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/faith_engagement_models.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class FaithEngagementRepository {
  const FaithEngagementRepository({
    required this.firestore,
    required this.churchId,
  });

  final FirebaseFirestore firestore;
  final String churchId;

  CollectionReference<Map<String, dynamic>> get _circles =>
      FirestorePaths.churchYouthCircles(firestore, churchId);
  CollectionReference<Map<String, dynamic>> get _reflections =>
      FirestorePaths.churchFaithReflections(firestore, churchId);
  CollectionReference<Map<String, dynamic>> get _engagement =>
      FirestorePaths.churchFaithEngagement(firestore, churchId);

  Stream<List<YouthCircle>> watchCircles({required AppUser? user}) {
    final groupIds = user?.churchGroupIds.toSet().take(30).toList() ?? const [];
    if (groupIds.isEmpty) return Stream.value(const []);
    return _circles
        .where('audienceGroupId', whereIn: groupIds)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map(YouthCircle.fromDoc).where((circle) {
        if (!circle.enabled || circle.title.isEmpty) return false;
        return circle.isVisibleTo(groupIds);
      }).toList();
      items.sort((a, b) => a.order.compareTo(b.order));
      return items;
    });
  }

  Stream<FaithReflection?> watchTodayReflection(DateTime day) {
    return _reflections.snapshots().map((snapshot) {
      for (final doc in snapshot.docs) {
        final reflection = FaithReflection.fromDoc(doc);
        if (reflection.isForDay(day)) return reflection;
      }
      return null;
    });
  }

  Stream<List<CircleResponse>> watchResponses(String circleId) {
    return _circles
        .doc(circleId)
        .collection('responses')
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(CircleResponse.fromDoc).toList());
  }

  Future<void> addResponse({
    required String circleId,
    required AppUser user,
    required String message,
    required String notificationBody,
  }) async {
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    await _circles.doc(circleId).collection('responses').add({
      'userId': user.uid,
      'userName': user.name,
      'userPhotoUrl': user.profilePhotoUrl,
      'message': normalized,
      'notificationBody': notificationBody.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteResponse(String circleId, String responseId) =>
      _circles.doc(circleId).collection('responses').doc(responseId).delete();

  String dailyProgressId(String userId, DateTime day) =>
      '${userId}_${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';

  Stream<DailyFaithProgress> watchDailyProgress(String userId, DateTime day) =>
      _engagement
          .doc(dailyProgressId(userId, day))
          .snapshots()
          .map((snapshot) => DailyFaithProgress.fromMap(snapshot.data()));

  Future<void> completeDailyStep({
    required String userId,
    required DateTime day,
    required String step,
  }) =>
      _engagement.doc(dailyProgressId(userId, day)).set({
        'userId': userId,
        'date': Timestamp.fromDate(DateTime(day.year, day.month, day.day)),
        'completedSteps': FieldValue.arrayUnion([step]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      watchAdminCircles() =>
          _circles.snapshots().map((snapshot) => snapshot.docs);
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      watchAdminReflections() =>
          _reflections.snapshots().map((snapshot) => snapshot.docs);

  Future<FaithLoopDashboardUpdate> getFaithLoopDashboardUpdate({
    DateTime? now,
    int days = 7,
  }) async {
    final current = now ?? DateTime.now();
    final firstDay = DateTime(current.year, current.month, current.day)
        .subtract(Duration(days: days - 1));
    final snapshot = await _engagement
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay),
        )
        .get();
    final records = snapshot.docs
        .map(DailyFaithProgressRecord.fromDoc)
        .where((record) => record.userId.isNotEmpty && record.date != null)
        .toList()
      ..sort((a, b) {
        final aDate = a.updatedAt ?? a.date!;
        final bDate = b.updatedAt ?? b.date!;
        return bDate.compareTo(aDate);
      });
    return FaithLoopDashboardUpdate(records: records);
  }

  Future<void> saveCircle(String? id, Map<String, dynamic> data) =>
      _save(_circles, id, data);
  Future<void> saveReflection(String? id, Map<String, dynamic> data) =>
      _save(_reflections, id, data);

  Future<void> deleteCircle(String id) =>
      _deleteWithSubcollection(_circles.doc(id), 'responses');
  Future<void> deleteReflection(String id) => _reflections.doc(id).delete();

  Future<void> queueFaithNotification({
    required String title,
    required String body,
    required String kind,
  }) =>
      FirestorePaths.churchNotificationRequests(firestore, churchId).add({
        'title': title.trim(),
        'body': body.trim(),
        'topic': 'church_$churchId',
        'kind': kind,
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> _save(
    CollectionReference<Map<String, dynamic>> collection,
    String? id,
    Map<String, dynamic> data,
  ) async {
    final doc = id == null ? collection.doc() : collection.doc(id);
    await doc.set({
      ...data,
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteWithSubcollection(
    DocumentReference<Map<String, dynamic>> parent,
    String childCollection,
  ) async {
    while (true) {
      final children =
          await parent.collection(childCollection).limit(400).get();
      if (children.docs.isEmpty) break;
      final batch = firestore.batch();
      for (final child in children.docs) {
        batch.delete(child.reference);
      }
      await batch.commit();
    }
    await parent.delete();
  }
}
