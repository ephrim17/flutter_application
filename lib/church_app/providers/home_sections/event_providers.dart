import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/home_section_fetchers/events_fetcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final eventsProvider = StreamProvider<List<Event>>((ref) {
  final repo = EventsFetcher(ref.read(firestoreProvider));
  return repo.watchAllActive(now: DateTime.now(), limit: 100);
});
