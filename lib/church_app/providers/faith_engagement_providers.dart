import 'package:flutter_application/church_app/models/faith_engagement_models.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/services/faith_engagement_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final faithEngagementRepositoryProvider =
    Provider.autoDispose<FaithEngagementRepository?>((ref) {
  final churchId = ref.watch(currentChurchIdProvider).asData?.value;
  if (churchId == null || churchId.trim().isEmpty) return null;
  return FaithEngagementRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );
});

final youthCirclesProvider =
    StreamProvider.autoDispose<List<YouthCircle>>((ref) {
  final repository = ref.watch(faithEngagementRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchCircles(
    user: ref.watch(appUserProvider).asData?.value,
  );
});

final quizChallengesProvider =
    StreamProvider.autoDispose<List<QuizChallenge>>((ref) {
  final repository = ref.watch(faithEngagementRepositoryProvider);
  return repository?.watchChallenges() ?? Stream.value(const []);
});

final todayReflectionProvider =
    StreamProvider.autoDispose<FaithReflection?>((ref) {
  final repository = ref.watch(faithEngagementRepositoryProvider);
  return repository?.watchTodayReflection(DateTime.now()) ?? Stream.value(null);
});

final dailyFaithProgressProvider =
    StreamProvider.autoDispose<DailyFaithProgress>((ref) {
  final repository = ref.watch(faithEngagementRepositoryProvider);
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (repository == null || uid == null) {
    return Stream.value(const DailyFaithProgress(completedSteps: {}));
  }
  return repository.watchDailyProgress(uid, DateTime.now());
});

final quizAttemptProvider =
    StreamProvider.autoDispose.family<QuizAttempt?, String>((ref, challengeId) {
  final repository = ref.watch(faithEngagementRepositoryProvider);
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (repository == null || uid == null) return Stream.value(null);
  return repository.watchQuizAttempt(challengeId, uid);
});

final circleResponsesProvider = StreamProvider.autoDispose
    .family<List<CircleResponse>, String>((ref, circleId) {
  final repository = ref.watch(faithEngagementRepositoryProvider);
  return repository?.watchResponses(circleId) ?? Stream.value(const []);
});
