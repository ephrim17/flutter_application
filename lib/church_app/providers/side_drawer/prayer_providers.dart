import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/services/side_drawer/prayer_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final prayerRepositoryProvider = Provider(
  (_) => PrayerRepository(),
);

final myPrayerRequestsProvider =
    StreamProvider<List<PrayerRequest>>(
  (ref) => ref.watch(prayerRepositoryProvider).watchMyPrayers(),
);

final allPrayerRequestsProvider =
    StreamProvider<List<PrayerRequest>>((ref) {
  return ref.read(prayerRepositoryProvider).getAllPrayers();
});