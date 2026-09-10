import 'package:flutter_application/church_app/models/church_member_directory_entry_model.dart';
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

/// Reduced roster (name/photo/dob/gender/marital status only) any approved
/// member can read — used by the Members screen for a non-admin viewer,
/// which cannot read [membersProvider]'s full `members` docs for anyone but
/// themselves.
final memberDirectoryProvider =
    FutureProvider<List<ChurchMemberDirectoryEntry>>((ref) async {
  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null) return const <ChurchMemberDirectoryEntry>[];

  final repo = MembersRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );

  return repo.getMemberDirectoryOnce();
});
