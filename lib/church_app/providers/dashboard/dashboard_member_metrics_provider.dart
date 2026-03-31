import 'package:flutter_application/church_app/models/dashboard_member_metrics_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/dashboard/dashboard_metrics_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardMetricsRepositoryProvider =
    Provider<DashboardMetricsRepository>((ref) {
  return DashboardMetricsRepository(ref.read(firestoreProvider));
});

final dashboardMemberMetricsProvider =
    FutureProvider<DashboardMemberMetrics>((ref) async {
  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null) {
    return DashboardMemberMetrics.empty;
  }
  final repo = ref.read(dashboardMetricsRepositoryProvider);
  return repo.getMemberMetrics(churchId);
});
