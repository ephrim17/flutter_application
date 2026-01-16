import 'package:flutter_application/church_app/models/home_section_models/pastor_model.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/home_section_fetchers/pastors_fetcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pastorsProvider = StreamProvider<List<Pastor>>((ref) {
  final repo = PastorsFetcher(ref.read(firestoreProvider));
  return repo.watchAllActive(now: DateTime.now(), limit: 100);
});
