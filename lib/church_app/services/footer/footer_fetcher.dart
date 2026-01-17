import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/footer_support/contact_item_model.dart';
import 'package:flutter_application/church_app/models/footer_support/social_icon_model.dart';

class FooterSupportFetcher {
  FooterSupportFetcher(this.firestore);

  final FirebaseFirestore firestore;

  Future<List<ContactItem>> fetchContacts() async {
    final snapshot = await firestore
        .collection('footerSupport')
        .doc('contacts')
        .collection('contactItems')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((doc) => ContactItem.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  Future<List<SocialIconModel>> fetchSocialIcons() async {
    final snapshot = await firestore
        .collection('footerSupport')
        .doc('social')
        .collection('socialItems')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((doc) => SocialIconModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }
}
