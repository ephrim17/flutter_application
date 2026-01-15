import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FirestoreRepository<T> {
  FirestoreRepository(this.db);

  final FirebaseFirestore db;

  CollectionReference<T> collectionRef();

  Future<List<T>> getAll() async {
    final snap = await collectionRef().get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Stream<List<T>> watchAll() {
    return collectionRef().snapshots().map((snap) {
      return snap.docs.map((d) => d.data()).toList();
    });
  }

  Future<String> add(T data) async {
    final doc = await collectionRef().add(data);
    return doc.id;
  }

  Future<void> set(String id, T data, {bool merge = true}) async {
    await collectionRef().doc(id).set(data, SetOptions(merge: merge));
  }

  Future<void> update(String id, Map<String, Object?> data) async {
    await collectionRef().doc(id).update(data);
  }

  Future<void> delete(String id) async {
    await collectionRef().doc(id).delete();
  }
}
