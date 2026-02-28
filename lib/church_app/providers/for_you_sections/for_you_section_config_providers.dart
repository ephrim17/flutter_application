import 'package:flutter_application/church_app/models/for_you_section_models/for_you_section_config_model.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/for_you_section/for_you_section_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final forYouSectionConfigsProvider =
    StreamProvider<List<ForYouSectionConfigModel>>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null) return const Stream.empty();

      final repo = ForYouSectionConfigRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
      );

      return repo.watchAll();
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});