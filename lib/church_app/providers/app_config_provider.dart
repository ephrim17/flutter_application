import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('config')
      .doc('app')
      .get();

  return AppConfig.fromMap(snapshot.data()!);
});
