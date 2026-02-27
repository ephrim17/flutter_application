import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class AppConfigRepository {
  final FirebaseFirestore firestore;
  final String churchId;

  AppConfigRepository({
    required this.firestore,
    required this.churchId,
  });

  Stream<AppConfig> watchAppConfig() {
    return FirestorePaths
        .churchAppConfig(firestore, churchId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) {
            throw Exception('App config does not exist');
          }
          return AppConfig.fromFirestore(data);
        });
  }
}