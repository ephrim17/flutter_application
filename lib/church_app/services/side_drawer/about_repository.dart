import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/about_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class AboutRepository extends ChurchScopedRepository {
  AboutRepository({
    required super.firestore,
    required super.churchId,
  });

  DocumentReference<AboutModel> docRef() {
    return FirestorePaths
        .churchAboutDoc(firestore, churchId)
        .withConverter<AboutModel>(
          fromFirestore: (snap, _) =>
              AboutModel.fromFirestore(snap.data()!),
          toFirestore: (model, _) => model.toMap(),
        );
  }

  Future<AboutModel> fetchAbout() async {
    final snap = await docRef().get();
    if (!snap.exists) {
      throw Exception('About content not found');
    }
    return snap.data()!;
  }

  Stream<AboutModel?> watchAbout() {
    return docRef().snapshots().map((snap) {
      if (!snap.exists) return null;
      return snap.data();
    });
  }
}