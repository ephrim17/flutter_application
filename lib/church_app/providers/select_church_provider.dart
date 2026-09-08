import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/services/church_repository.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

// TODO(user-church-decoupling): re-export only, kept so this file's existing
// importers keep compiling after the firestoreProvider collapse (KT Files/
// architecture/user-church-decoupling-migration.md §3, Phase 0). The
// canonical declaration lives in services/firestore/firestore_provider.dart —
// repoint importers there directly and delete this export once that's done.
// Three import paths for one provider is the same ambiguity that caused the
// duplication this collapse fixes.
export 'package:flutter_application/church_app/services/firestore/firestore_provider.dart'
    show firestoreProvider;

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

final allChurchesProvider = StreamProvider<List<Church>>((ref) {
  final repository = ref.watch(churchRepositoryProvider);
  return repository.getAllChurches();
});

final churchByIdProvider = FutureProvider.family<Church?, String>((
  ref,
  churchId,
) async {
  if (churchId.trim().isEmpty) return null;
  final repository = ref.watch(churchRepositoryProvider);
  return repository.getChurchById(churchId);
});
