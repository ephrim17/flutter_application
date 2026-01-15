import 'package:flutter_application/church_app/models/home_section_models/home_section_config_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/home_section_fetchers/home_section_config_fetcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeSectionConfigsProvider =
    StreamProvider<List<HomeSectionConfigModel>>((ref) {
  final repo = HomeSectionFetcher(ref.read(firestoreProvider));
  return repo.watchSections();
});
