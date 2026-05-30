import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/bible_version_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_catalog.dart';

class BibleVersionsRepository {
  BibleVersionsRepository({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> collectionRef() {
    return FirestorePaths.bibleVersionsCollection(firestore);
  }

  Stream<List<BibleVersion>> watchAvailableVersions() {
    return collectionRef().snapshots().map((snapshot) {
      final versions = snapshot.docs
          .map((doc) {
            final version = BibleVersion.fromMap(doc.id, doc.data());
            final bookFileNames = version.bookFileNames.isEmpty
                ? bibleBookFileNames
                : version.bookFileNames;

            return BibleVersion(
              id: version.id,
              title: version.title,
              subtitle: version.subtitle,
              languageLabel: version.languageLabel,
              description: version.description,
              bookFileNames: bookFileNames,
              assetBasePath: version.assetBasePath,
              downloadBaseUrl: version.downloadBaseUrl,
              storagePath: version.storagePath,
              enabled: version.enabled,
              sortOrder: version.sortOrder,
              contentVersion: version.contentVersion,
            );
          })
          .where((version) => version.enabled)
          .toList(growable: false)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return versions;
    });
  }
}
