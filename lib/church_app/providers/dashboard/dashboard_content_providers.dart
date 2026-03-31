import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/announcement_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/app_config_repository.dart';
import 'package:flutter_application/church_app/services/home_section/announcements_repository.dart';
import 'package:flutter_application/church_app/services/home_section/events_repository.dart';
import 'package:flutter_application/church_app/services/side_drawer/prayer_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardAnnouncementsProvider =
    FutureProvider<List<Announcement>>((ref) async {
  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null) {
    return const <Announcement>[];
  }

  final repo = AnnouncementsRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );
  return repo.getAllActiveOnce(
    now: DateTime.now(),
    limit: 100,
  );
});

final dashboardEventsProvider = FutureProvider<List<Event>>((ref) async {
  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null) {
    return const <Event>[];
  }

  final repo = EventsRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );
  return repo.getAllActiveOnce(
    now: DateTime.now(),
  );
});

final dashboardPrayerRequestsProvider =
    FutureProvider<List<PrayerRequest>>((ref) async {
  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null || churchId.trim().isEmpty) {
    return const <PrayerRequest>[];
  }

  final repo = PrayerRepository(
    firestore: ref.read(firestoreProvider),
    auth: ref.read(firebaseAuthProvider),
    churchId: churchId,
  );
  return repo.getAllPrayersOnce();
});

final dashboardAppConfigProvider = FutureProvider<AppConfig>((ref) async {
  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null) {
    return AppConfig.fallback();
  }

  final repo = AppConfigRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );
  return repo.getAppConfigOnce();
});
