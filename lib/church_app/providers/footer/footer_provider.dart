import 'package:flutter_application/church_app/models/footer_support_models/contact_item_model.dart';
import 'package:flutter_application/church_app/models/footer_support_models/social_icon_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/footer/footer_fetcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


final footerContactsProvider =
    StreamProvider<List<ContactItem>>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null) return const Stream.empty();

      final repo = FooterSupportRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
      );

      return repo.watchActiveContacts();
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

final footerSocialIconsProvider =
    StreamProvider<List<SocialIconModel>>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null) return const Stream.empty();

      final repo = FooterSupportRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
      );

      return repo.watchActiveSocialIcons();
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});