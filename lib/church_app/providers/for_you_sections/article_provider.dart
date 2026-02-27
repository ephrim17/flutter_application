import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/article_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/for_you_section/article_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final articlesProvider = StreamProvider<List<Article>>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);
  
  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null) {
        return const Stream.empty();
      }

      final repo = ArticleRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
      );

      return repo.watchAll(limit: 100);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});
