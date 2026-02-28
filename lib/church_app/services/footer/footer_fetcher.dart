import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/footer_support_models/contact_item_model.dart';
import 'package:flutter_application/church_app/models/footer_support_models/social_icon_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class FooterSupportRepository extends ChurchScopedRepository {
  FooterSupportRepository({
    required super.firestore,
    required super.churchId,
  });

  CollectionReference<ContactItem> _contactsRef() {
    return FirestorePaths
        .churchContactItems(firestore, churchId)
        .withConverter<ContactItem>(
          fromFirestore: (snap, _) =>
              ContactItem.fromFirestore(snap.id, snap.data()!),
          toFirestore: (model, _) => model.toMap(),
        );
  }

  CollectionReference<SocialIconModel> _socialRef() {
    return FirestorePaths
        .churchSocialItems(firestore, churchId)
        .withConverter<SocialIconModel>(
          fromFirestore: (snap, _) =>
              SocialIconModel.fromFirestore(snap.id, snap.data()!),
          toFirestore: (model, _) => model.toMap(),
        );
  }

  Stream<List<ContactItem>> watchActiveContacts() {
    return _contactsRef()
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Stream<List<SocialIconModel>> watchActiveSocialIcons() {
    return _socialRef()
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }
}