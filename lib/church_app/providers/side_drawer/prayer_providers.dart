import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/prayer_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final prayerRepositoryForChurchProvider =
    Provider.autoDispose.family<PrayerRepository, String>((ref, churchId) {
  return PrayerRepository(
    firestore: ref.read(firestoreProvider),
    auth: ref.read(firebaseAuthProvider),
    churchId: churchId,
  );
});

final prayerRepositoryProvider = Provider.autoDispose<PrayerRepository>((ref) {
  final churchId = ref.watch(currentChurchIdProvider).asData?.value;
  if (churchId == null || churchId.trim().isEmpty) {
    throw Exception("Church not selected");
  }

  return ref.watch(prayerRepositoryForChurchProvider(churchId));
});

final myPrayerRequestsProvider =
    StreamProvider<List<PrayerRequest>>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null || churchId.trim().isEmpty) {
        return Stream.value(const <PrayerRequest>[]);
      }

      return ref
          .watch(prayerRepositoryForChurchProvider(churchId))
          .watchMyPrayers();
    },
    loading: () => const Stream.empty(),
    error: (error, stackTrace) => Stream.error(error, stackTrace),
  );
});

final allPrayerRequestsProvider = StreamProvider<List<PrayerRequest>>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null || churchId.trim().isEmpty) {
        return Stream.value(const <PrayerRequest>[]);
      }

      return ref
          .watch(prayerRepositoryForChurchProvider(churchId))
          .getAllPrayers();
    },
    loading: () => const Stream.empty(),
    error: (error, stackTrace) => Stream.error(error, stackTrace),
  );
});
