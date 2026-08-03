import 'package:flutter_application/church_app/models/learning_module_models.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/learning_module_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final learningModuleRepositoryProvider = Provider<LearningModuleRepository>(
  (ref) => LearningModuleRepository(firestore: ref.read(firestoreProvider)),
);

final publishedLearningModulesProvider =
    StreamProvider.autoDispose<List<LearningModule>>((ref) {
  final churchId = ref.watch(currentChurchIdProvider).asData?.value;
  if (churchId == null || churchId.isEmpty) return Stream.value(const []);
  return ref
      .watch(learningModuleRepositoryProvider)
      .watchResolvedPublishedModules(churchId);
});

final learningProgressProvider =
    StreamProvider.autoDispose<LearningProgress>((ref) {
  final churchId = ref.watch(currentChurchIdProvider).asData?.value;
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (churchId == null || churchId.isEmpty || userId == null) {
    return Stream.value(
      const LearningProgress(completedSectionIds: {}, attempts: {}),
    );
  }
  return ref.watch(learningModuleRepositoryProvider).watchProgress(
        churchId: churchId,
        userId: userId,
      );
});
