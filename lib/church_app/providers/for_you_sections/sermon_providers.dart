import 'package:flutter_application/church_app/models/for_you_section_model/sermon_model.dart';
import 'package:flutter_application/church_app/services/for_you_section/sermon_repsitory.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final sermonRepositoryProvider =
    Provider((ref) => SermonRepository());

final sermonsProvider =
    FutureProvider<List<SermonModel>>((ref) {
  return ref.read(sermonRepositoryProvider).fetchSermons();
});
