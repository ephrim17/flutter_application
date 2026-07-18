import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class EventsRepository extends ChurchScopedRepository {
  EventsRepository({
    required super.firestore,
    required super.churchId,
  });

  CollectionReference<Event> collectionRef() {
    return FirestorePaths.churchEvents(firestore, churchId)
        .withConverter<Event>(
      fromFirestore: (snap, _) => Event.fromFirestore(snap),
      toFirestore: (a, _) => a.toMap(),
    );
  }

  Stream<List<Event>> watchActiveForBanner({
    required DateTime now,
    int limit = 3,
  }) {
    return collectionRef()
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) => _sortEventsBySchedule(
            s.docs.map((d) => d.data()).where(
                  (event) =>
                      event.expiryAt == null || event.expiryAt!.isAfter(now),
                ),
          ).take(limit).toList(),
        );
  }

  Stream<List<Event>> watchAllActive({
    required DateTime now,
    int limit = 50,
  }) {
    return collectionRef()
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) => _sortEventsBySchedule(
            s.docs.map((d) => d.data()).where(
                  (event) =>
                      event.expiryAt == null || event.expiryAt!.isAfter(now),
                ),
          ).take(limit).toList(),
        );
  }

  Future<List<Event>> getAllActiveOnce({
    required DateTime now,
    int limit = 50,
  }) async {
    final snapshot = await collectionRef()
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .get();

    return _sortEventsBySchedule(
      snapshot.docs.map((doc) => doc.data()).where(
            (event) => event.expiryAt == null || event.expiryAt!.isAfter(now),
          ),
    ).take(limit).toList(growable: false);
  }
}

List<Event> _sortEventsBySchedule(Iterable<Event> events) {
  final sorted = events.toList(growable: false);
  sorted.sort((a, b) {
    final aDate = a.startAt ?? a.expiryAt;
    final bDate = b.startAt ?? b.expiryAt;
    if (aDate == null && bDate == null) return a.title.compareTo(b.title);
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return aDate.compareTo(bDate);
  });
  return sorted;
}
