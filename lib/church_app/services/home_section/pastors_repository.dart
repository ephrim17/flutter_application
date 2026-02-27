import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/home_section_models/pastor_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class PastorsRepository extends ChurchScopedRepository {
  PastorsRepository({
    required super.firestore,
    required super.churchId,
  });

  CollectionReference<Pastor> collectionRef() {
    return FirestorePaths.churchPastors(firestore, churchId)
        .withConverter<Pastor>(
          fromFirestore: (snap, _) => Pastor.fromFirestore(snap),
          toFirestore: (a, _) => a.toMap(),
        );
  }

  Stream<List<Pastor>> watchActiveForBanner({
    required DateTime now,
    int limit = 3,
  }) {
    return collectionRef()
        //.where('isActive', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Stream<List<Pastor>> watchAllActive({
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
