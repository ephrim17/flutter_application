import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_crud.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class EventsRepository extends FirestoreRepository<Event> {
  EventsRepository(super.db);

  @override
  CollectionReference<Event> collectionRef() {
    return db
        .collection(FirestorePaths.events)
        .withConverter<Event>(
          fromFirestore: (snap, _) => Event.fromDoc(snap),
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
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Stream<List<Event>> watchAllActive({
    required DateTime now,
    int limit = 50,
  }) {
    return collectionRef()
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }
}
