

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/article_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class ArticleRepository {
  final FirebaseFirestore firestore;

  ArticleRepository(this.firestore);

  Stream<List<Article>> watchAll({
    int limit = 50,
  }) {
    return firestore
        .collection(FirestorePaths.articles)
        //.orderBy('createdAt', descending: true)
        //.limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Article.fromFirestore(doc))
              .toList(),
        );
  }
}
