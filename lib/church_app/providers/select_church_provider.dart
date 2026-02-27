import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/services/church_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

/// Firestore instance provider
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final selectedChurchProvider = StateProvider<Church?>((ref) => null);

/// Repository provider
final churchRepositoryProvider = Provider<ChurchRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ChurchRepository(firestore);
});

/// Stream provider for enabled churches
final churchesProvider = StreamProvider<List<Church>>((ref) {
  final repository = ref.watch(churchRepositoryProvider);
  return repository.getEnabledChurches();
});