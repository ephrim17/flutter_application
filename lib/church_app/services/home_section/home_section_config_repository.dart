import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/home_section_models/home_section_config_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class HomeSectionConfigRepository {
  HomeSectionConfigRepository(this.db);
  final FirebaseFirestore db;

  Stream<List<HomeSectionConfigModel>> watchSections() {
    return db.collection(FirestorePaths.homeSections).snapshots().map(
          (snapshot) => snapshot.docs
              .map((d) => HomeSectionConfigModel.fromDoc(d))
              .toList(),
        );
  }
}
