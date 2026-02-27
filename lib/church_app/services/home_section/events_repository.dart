import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';

class EventsRepository extends ChurchScopedRepository{
  EventsRepository({
    required super.firestore,
    required super.churchId,
  });

 CollectionReference<Event> collectionRef() {
    return 
      firestore
      .collection('churches')
      .doc('tnbm')
      .collection('events')
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
