import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/home_section_models/home_section_config_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class HomeSectionConfigRepository extends ChurchScopedRepository {
  HomeSectionConfigRepository({
    required super.firestore,
    required super.churchId,
  });

  CollectionReference<HomeSectionConfigModel> collectionRef() {
    return FirestorePaths
        .churchHomeSections(firestore, churchId)
        .withConverter<HomeSectionConfigModel>(
          fromFirestore: (snap, _) =>
              HomeSectionConfigModel.fromFirestore(snap),
          toFirestore: (model, _) => model.toMap(),
        );
  }

  Stream<List<HomeSectionConfigModel>> watchAll({
    int limit = 50,
  }) {
    return collectionRef()
        .orderBy('order') // recommended
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }
}