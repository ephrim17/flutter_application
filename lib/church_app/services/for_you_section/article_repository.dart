

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/article_model.dart';

class ArticleRepository {
  final FirebaseFirestore firestore;

  ArticleRepository(this.firestore);

  Stream<List<Article>> watchAll({
    int limit = 50,
  }) {
    return firestore
        .collection('articles')
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
