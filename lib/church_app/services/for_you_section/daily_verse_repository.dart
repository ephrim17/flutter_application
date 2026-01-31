import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/daily_verse_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_crud.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class DailyVerseRepository extends FirestoreRepository<DailyVerse> {
  DailyVerseRepository(super.db);

  @override
  CollectionReference<DailyVerse> collectionRef() {
    return db
        .collection(FirestorePaths.dailyVerse)
        .withConverter<DailyVerse>(
          fromFirestore: (snap, _) => DailyVerse.fromDoc(snap),
          toFirestore: (a, _) => a.toMap(),
        );
  }

  Stream<List<DailyVerse>> watchActiveForBanner({
    required DateTime now,
    int limit = 3,
  }) {
    return collectionRef()
        //.where('isActive', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Stream<List<DailyVerse>> watchAllActive({
    required DateTime now,
    int limit = 50,
  }) {
    return collectionRef()
        //.where('isActive', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }
}
