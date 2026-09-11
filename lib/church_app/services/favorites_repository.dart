import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

/// Person-owned Bible favorites — `users/{uid}/favorites/{verseKey}`
/// (§5.1/Phase 4). `verseKey` reuses the same `{book}_{chapter}_{verse}`
/// string the app has always used as a SharedPreferences key, so migrating
/// a key across stores needs no reformatting.
class FavoritesRepository {
  FavoritesRepository({required this.firestore, required this.uid});

  final FirebaseFirestore firestore;
  final String uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirestorePaths.userFavorites(firestore, uid);

  Future<Set<String>> fetchKeys() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  Future<void> addKey(String key) {
    return _collection.doc(key).set({
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeKey(String key) {
    return _collection.doc(key).delete();
  }

  /// Merges local-only keys into Firestore — used once per load to carry
  /// forward anything saved locally before this device last synced,
  /// without ever losing a highlight (Phase 4).
  Future<void> mergeKeys(Set<String> keys) async {
    if (keys.isEmpty) return;
    final batch = firestore.batch();
    for (final key in keys) {
      batch.set(_collection.doc(key), {
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
