import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/dashboard_member_metrics_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class DashboardMetricsRepository {
  DashboardMetricsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<DashboardMemberMetrics> getMemberMetrics(String churchId) async {
    final snapshot = await FirestorePaths.churchDashboardMetricDoc(
      _firestore,
      churchId,
      'members',
    ).get();
    final data = snapshot.data();
    if (data == null) {
      return DashboardMemberMetrics.empty;
    }
    return DashboardMemberMetrics.fromMap(data);
  }

  Stream<DashboardMemberMetrics> watchMemberMetrics(String churchId) {
    return FirestorePaths.churchDashboardMetricDoc(
      _firestore,
      churchId,
      'members',
    ).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return DashboardMemberMetrics.empty;
      }
      return DashboardMemberMetrics.fromMap(data);
    });
  }
}
