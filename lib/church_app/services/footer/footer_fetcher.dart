import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/footer_support_models/contact_item_model.dart';
import 'package:flutter_application/church_app/models/footer_support_models/social_icon_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class FooterSupportFetcher {
  FooterSupportFetcher(this.firestore);

  final FirebaseFirestore firestore;

  Future<List<ContactItem>> fetchContacts() async {
    final snapshot = await FirestorePaths.contactItems(firestore)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((doc) => ContactItem.fromFirestore(doc.id, doc.data() as Map<String, dynamic>,))
        .toList();
  }

  Future<List<SocialIconModel>> fetchSocialIcons() async {
    final snapshot = await FirestorePaths.socialItems(firestore)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((doc) => SocialIconModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }
}
