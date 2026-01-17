import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/about_model.dart';

class AboutFetcher {
  final FirebaseFirestore db;

  AboutFetcher(this.db);

  Future<AboutModel> fetchAbout() async {
    final snap = await db.collection('about').doc('main').get();
    if (!snap.exists) {
      throw Exception('About content not found');
    }
    return AboutModel.fromFirestore(snap.data()!);
  }
}
