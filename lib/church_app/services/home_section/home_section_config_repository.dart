import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/home_section_models/home_section_config_model.dart';

class HomeSectionConfigRepository {
  HomeSectionConfigRepository(this.db);
  final FirebaseFirestore db;

  Stream<List<HomeSectionConfigModel>> watchSections() {
    return db.collection('home_sections').snapshots().map(
          (snapshot) => snapshot.docs
              .map((d) => HomeSectionConfigModel.fromDoc(d))
              .toList(),
        );
  }
}
