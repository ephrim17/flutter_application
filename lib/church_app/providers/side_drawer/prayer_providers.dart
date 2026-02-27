import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/prayer_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final prayerRepositoryProvider =
    Provider.autoDispose<PrayerRepository>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null) {
        throw Exception("Church not selected");
      }

      return PrayerRepository(
        firestore: ref.read(firestoreProvider),
        auth: ref.read(firebaseAuthProvider),
        churchId: churchId,
      );
    },
    loading: () => throw Exception("Church loading"),
    error: (e, _) => throw e,
  );
});

final myPrayerRequestsProvider =
    StreamProvider<List<PrayerRequest>>(
  (ref) => ref.watch(prayerRepositoryProvider).watchMyPrayers(),
);

final allPrayerRequestsProvider =
    StreamProvider<List<PrayerRequest>>((ref) {
  return ref.read(prayerRepositoryProvider).getAllPrayers();
});