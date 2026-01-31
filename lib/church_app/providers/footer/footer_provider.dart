import 'package:flutter_application/church_app/models/footer_support_models/contact_item_model.dart';
import 'package:flutter_application/church_app/models/footer_support_models/social_icon_model.dart';
import 'package:flutter_application/church_app/services/footer/footer_fetcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final footerSupportFetcherProvider =
    Provider<FooterSupportFetcher>((ref) {
  return FooterSupportFetcher(FirebaseFirestore.instance);
});

final footerContactsProvider =
    FutureProvider<List<ContactItem>>((ref) async {
  final fetcher = ref.watch(footerSupportFetcherProvider);
  return fetcher.fetchContacts();
});

final footerSocialIconsProvider =
    FutureProvider<List<SocialIconModel>>((ref) async {
  final fetcher = ref.watch(footerSupportFetcherProvider);
  return fetcher.fetchSocialIcons();
});
