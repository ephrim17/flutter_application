import 'package:flutter_application/church_app/models/home_section_models/service_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/home_section_fetchers/service_fetcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final servicesProvider = StreamProvider<List<ServiceModel>>((ref) {
  final repo = ServicesFetcher(ref.read(firestoreProvider));
  return repo.watchAllActive(now: DateTime.now(), limit: 100);
});
