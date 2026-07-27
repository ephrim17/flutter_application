import 'package:flutter_application/church_app/models/live_church_model.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final liveChurchStatusProvider =
    StreamProvider.autoDispose<LiveChurchStatus>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null) return const Stream.empty();
      return FirestorePaths.churchLiveChurchStatus(
        ref.read(firestoreProvider),
        churchId,
      ).snapshots().map((snapshot) {
        return LiveChurchStatus.fromMap(snapshot.data());
      });
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});
