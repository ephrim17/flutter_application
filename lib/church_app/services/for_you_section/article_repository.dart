import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/helpers/church_scoped.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/article_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';


class ArticleRepository extends ChurchScopedRepository {
  ArticleRepository({
    required super.firestore,
    required super.churchId,
  });

  /// Typed collection reference
  CollectionReference<Article> collectionRef() {
    return FirestorePaths
        .churchDailyArticles(firestore, churchId)
        .withConverter<Article>(
          fromFirestore: (snap, _) => Article.fromFirestore(snap),
          toFirestore: (article, _) => article.toMap(),
        );
  }

  Stream<List<Article>> watchAll({
    int limit = 50,
  }) {
    return collectionRef()
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.data())
              .toList(),
        );
  }
}