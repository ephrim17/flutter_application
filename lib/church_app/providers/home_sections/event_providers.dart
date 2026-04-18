import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/home_section/events_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final eventsProvider = StreamProvider.autoDispose<List<Event>>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null) return const Stream.empty();
      final repo = EventsRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
      );

      return repo.watchAllActive(
        now: DateTime.now(),
        limit: 12,
      );
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});
