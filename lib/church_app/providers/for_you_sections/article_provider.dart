import 'package:flutter_application/church_app/models/for_you_section_model/article_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/for_you_section/article_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';


final articleRepositoryProvider = Provider<ArticleRepository>((ref) {
  return ArticleRepository(ref.read(firestoreProvider));
});

final articlesProvider = StreamProvider<List<Article>>((ref) {
  final repo = ref.read(articleRepositoryProvider);
  return repo.watchAll(limit: 100);
});
