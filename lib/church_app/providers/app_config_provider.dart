import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final appConfigProvider = StreamProvider<AppConfig>((ref) {
  return FirebaseFirestore.instance
      .collection(FirestorePaths.config)
      .doc('app')
      .snapshots()
      .map((snapshot) {
        return AppConfig.fromMap(snapshot.data()!);
      });
});

