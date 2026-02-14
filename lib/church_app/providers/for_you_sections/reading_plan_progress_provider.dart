import 'package:flutter_application/church_app/services/for_you_section/reading_plan_progress_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

final readingPlanProgressProvider =
    StateNotifierProvider.family<
        ReadingPlanProgressNotifier,
        AsyncValue<List<int>>,
        String>((ref, month) {
  return ReadingPlanProgressNotifier(month);
});

class ReadingPlanProgressNotifier
    extends StateNotifier<AsyncValue<List<int>>> {
  final String month;
  final ReadingPlanProgressService _service =
      ReadingPlanProgressService();

  ReadingPlanProgressNotifier(this.month)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final days = await _service.fetchCompletedDays(month);
      state = AsyncValue.data(days);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleDay(int day) async {
    final current = state.value ?? [];

    List<int> updated = List.from(current);

    if (updated.contains(day)) {
      updated.remove(day);
    } else {
      updated.add(day);
    }

    state = AsyncValue.data(updated);

    await _service.updateCompletedDays(month, updated);
  }
}
