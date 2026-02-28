import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/for_you_section/reading_plan_progress_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

final readingPlanProgressRepositoryProvider =
    Provider<ReadingPlanProgressRepository?>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final user = auth.currentUser;

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null || user == null) return null;

      return ReadingPlanProgressRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
        uid: user.uid,
      );
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

final readingPlanProgressProvider =
    StateNotifierProvider.family<
        ReadingPlanProgressNotifier,
        AsyncValue<List<int>>,
        String>((ref, month) {

  final repo = ref.watch(readingPlanProgressRepositoryProvider);

  return ReadingPlanProgressNotifier(
    month: month,
    repository: repo,
  );
});

class ReadingPlanProgressNotifier
    extends StateNotifier<AsyncValue<List<int>>> {

  final String month;
  final ReadingPlanProgressRepository? repository;

  ReadingPlanProgressNotifier({
    required this.month,
    required this.repository,
  }) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (repository == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final days =
          await repository!.fetchCompletedDays(month);
      state = AsyncValue.data(days);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleDay(int day) async {
    if (repository == null) return;

    final current = state.value ?? [];
    final updated = List<int>.from(current);

    if (updated.contains(day)) {
      updated.remove(day);
    } else {
      updated.add(day);
    }

    state = AsyncValue.data(updated);

    await repository!
        .updateCompletedDays(month, updated);
  }
}