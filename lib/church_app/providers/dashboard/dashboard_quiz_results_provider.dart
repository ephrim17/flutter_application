import 'package:flutter_application/church_app/models/faith_engagement_models.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/faith_engagement_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardQuizResultsProvider =
    FutureProvider<List<QuizDashboardResult>>((ref) async {
  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null || churchId.trim().isEmpty) return const [];
  return FaithEngagementRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  ).getQuizDashboardResults();
});

final dashboardFaithLoopUpdatesProvider =
    FutureProvider<FaithLoopDashboardUpdate>((ref) async {
  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null || churchId.trim().isEmpty) {
    return const FaithLoopDashboardUpdate(records: []);
  }
  return FaithEngagementRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  ).getFaithLoopDashboardUpdate();
});
