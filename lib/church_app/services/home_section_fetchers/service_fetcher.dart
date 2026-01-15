import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/home_section_models/service_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_crud.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class ServicesFetcher extends FirestoreRepository<ServiceModel> {
  ServicesFetcher(super.db);

  @override
  CollectionReference<ServiceModel> collectionRef() {
    return db
        .collection(FirestorePaths.services)
        .withConverter<ServiceModel>(
          fromFirestore: (snap, _) => ServiceModel.fromDoc(snap),
          toFirestore: (a, _) => a.toMap(),
        );
  }

  Stream<List<ServiceModel>> watchActiveForBanner({
    required DateTime now,
    int limit = 3,
  }) {
    return collectionRef()
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Stream<List<ServiceModel>> watchAllActive({
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
