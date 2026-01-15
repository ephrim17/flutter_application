import 'package:flutter_application/church_app/models/announcements/announcement_model.dart';
import 'package:flutter_application/church_app/services/announcements/announcement_fetcher.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final announcementsProvider = StreamProvider<List<Announcement>>((ref) {
  final repo = AnnouncementFetcher(ref.read(firestoreProvider));
  return repo.watchAllActive(now: DateTime.now(), limit: 100);
});
