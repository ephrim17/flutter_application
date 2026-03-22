import 'package:flutter_application/church_app/models/church_group_member_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final churchGroupMembersProvider =
    StreamProvider.family<List<ChurchGroupMember>, String>((ref, groupId) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null) return const Stream.empty();

      final repo = MembersRepository(
        firestore: ref.read(firestoreProvider),
        churchId: churchId,
      );

      return repo.watchGroupMembers(groupId);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});
