import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/for_you_section_config_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class ForYouSectionConfigRepository {
  ForYouSectionConfigRepository(this.db);
  final FirebaseFirestore db;

  Stream<List<ForYouSectionConfigModel>> watchSections() {
    return db.collection(FirestorePaths.forYouSection).snapshots().map(
          (snapshot) => snapshot.docs
              .map((d) => ForYouSectionConfigModel.fromDoc(d))
              .toList(),
        );
  }
}
