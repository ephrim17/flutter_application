import 'package:flutter_application/church_app/models/side_drawer_models/about_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/about_repository.dart';

final aboutRepositoryProvider = Provider<AboutFetcher>((ref) {
  return AboutFetcher(ref.read(firestoreProvider));
});

final aboutProvider = FutureProvider<AboutModel>((ref) {
  final repo = ref.read(aboutRepositoryProvider);
  return repo.fetchAbout();
});