import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final membersProvider = StreamProvider<List<AppUser>>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null) return const Stream.empty();

      final repo = MembersRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
      );

      return repo.getMembers();
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});