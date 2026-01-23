import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/for_you_section_model/shorts_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final shortsRepositoryProvider = Provider((ref) {
  return ShortsRepository(FirebaseFirestore.instance);
});

class ShortsRepository {
  ShortsRepository(this.db);
  final FirebaseFirestore db;

  Stream<List<ShortModel>> watchActiveShorts(String channelId) {
    return db
        .collection('shorts')
        //.where('isActive', isEqualTo: true)
        //.where('channelId', isEqualTo: channelId)
        //.orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ShortModel.fromDoc(d)).toList());
  }
}
