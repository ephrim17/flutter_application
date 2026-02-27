import 'package:cloud_firestore/cloud_firestore.dart';

abstract class ChurchScopedRepository {
  final FirebaseFirestore firestore;
  final String churchId;

  ChurchScopedRepository({
    required this.firestore,
    required this.churchId,
  });

  DocumentReference churchDoc() {
    return firestore.collection('churches').doc(churchId);
  }
}