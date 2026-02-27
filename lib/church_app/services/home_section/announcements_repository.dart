import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/home_section_models/announcement_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class AnnouncementsRepository extends ChurchScopedRepository {
  AnnouncementsRepository({
    required super.firestore,
    required super.churchId,
  });

  CollectionReference<Announcement> collectionRef() {
    return 
        FirestorePaths.churchAnnouncements(firestore, churchId)
        .withConverter<Announcement>(
          fromFirestore: (snap, _) => Announcement.fromFirestore(snap),
          toFirestore: (a, _) => a.toMap(),
        );
  }

  Stream<List<Announcement>> watchActiveForBanner({
    required DateTime now,
    int limit = 3,
  }) {
    return collectionRef()
        .where('isActive', isEqualTo: true)
        .orderBy('priority')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Stream<List<Announcement>> watchAllActive({
    required DateTime now,
    int limit = 50,
  }) {
    return collectionRef()
        .where('isActive', isEqualTo: true)
        .orderBy('priority')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }
}