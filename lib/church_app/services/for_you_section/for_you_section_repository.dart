import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/for_you_section_config_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class ForYouSectionConfigRepository extends ChurchScopedRepository {
  ForYouSectionConfigRepository({
    required super.firestore,
    required super.churchId,
  });

  CollectionReference<ForYouSectionConfigModel> collectionRef() {
    return FirestorePaths
        .churchForYouSections(firestore, churchId)
        .withConverter<ForYouSectionConfigModel>(
          fromFirestore: (snap, _) =>
              ForYouSectionConfigModel.fromFirestore(snap),
              toFirestore: (model, _) => model.toMap(),
        );
  }

  Stream<List<ForYouSectionConfigModel>> watchAll({
    int limit = 50,
  }) {
    return collectionRef()
        .orderBy('order') // recommended
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }
}