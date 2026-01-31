import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/sermon_model.dart';

class SermonRepository {
  final _firestore = FirebaseFirestore.instance;

  Future<List<SermonModel>> fetchSermons() async {
    final snap = await _firestore
        .collection('sermons')
        //.where('isActive', isEqualTo: true)
        //.orderBy('createdAt', descending: true)
        .get();
      //print("<<<< snaps >>>>");
    //print(snap.docs);
    return snap.docs
        .map((d) => SermonModel.fromFirestore(d.id, d.data()))
        .toList();
  }
}
