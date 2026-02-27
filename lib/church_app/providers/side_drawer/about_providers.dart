import 'package:flutter_application/church_app/models/side_drawer_models/about_model.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/about_repository.dart';

final aboutProvider =
    FutureProvider<AboutModel?>((ref) async {
  final churchId =
      await ref.watch(currentChurchIdProvider.future);

  if (churchId == null) return null;

  final repo = AboutRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );

  return repo.fetchAbout();
});