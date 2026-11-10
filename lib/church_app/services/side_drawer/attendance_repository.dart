import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/attendance_service_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

/// Reads and writes `churches/{churchId}/services`.
///
/// Every method is church-scoped through [churchId]; there is no cross-church
/// read here and no reason there ever should be — attendance is the most
/// church-private record the app keeps.
class AttendanceRepository {
  const AttendanceRepository({
    required this.firestore,
    required this.churchId,
  });

  final FirebaseFirestore firestore;
  final String churchId;

  CollectionReference<Map<String, dynamic>> collectionRef() {
    return FirestorePaths.churchServices(firestore, churchId);
  }

  /// How many services the screen holds at once. A church recording weekly
  /// has five years of history inside this; the stats only ever look at the
  /// most recent handful.
  static const int _serviceCap = 260;

  Stream<List<AttendanceService>> watchServices() {
    return collectionRef()
        .orderBy('date', descending: true)
        .limit(_serviceCap)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AttendanceService.fromFirestore(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  Stream<AttendanceService?> watchService(String serviceId) {
    return collectionRef().doc(serviceId).snapshots().map(
          (doc) => doc.exists
              ? AttendanceService.fromFirestore(doc.id, doc.data()!)
              : null,
        );
  }

  /// Creates the service and returns its id, so the caller can go straight
  /// on to marking attendance without a round trip to find it again.
  Future<String> createService({
    required DateTime date,
    required String type,
    required String subheader,
    required int visitorCount,
    required int childrenCount,
    required String notes,
    required String createdBy,
  }) async {
    final doc = await collectionRef().add({
      ...AttendanceService(
        id: '',
        date: date,
        type: type,
        subheader: subheader,
        visitorCount: visitorCount,
        childrenCount: childrenCount,
        notes: notes,
        createdBy: createdBy,
      ).toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateServiceDetails({
    required String serviceId,
    required DateTime date,
    required String type,
    required String subheader,
    required int visitorCount,
    required int childrenCount,
    required String notes,
  }) {
    // Deliberately not `present` — the details form and the marking sheet
    // write disjoint fields, so saving details can never silently discard
    // attendance someone else is marking at the same time.
    return collectionRef().doc(serviceId).update({
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'type': type,
      'subheader': subheader,
      'visitorCount': visitorCount,
      'childrenCount': childrenCount,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> savePresent({
    required String serviceId,
    required Set<String> present,
  }) {
    return collectionRef().doc(serviceId).update({
      'present': present.toList(growable: false),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteService(String serviceId) {
    return collectionRef().doc(serviceId).delete();
  }
}
