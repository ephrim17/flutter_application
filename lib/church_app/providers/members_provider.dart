import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final membersProvider = FutureProvider<List<ChurchMembership>>((ref) async {
  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null) return const <ChurchMembership>[];

  final repo = MembersRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );

  return repo.getMembersOnce();
});
