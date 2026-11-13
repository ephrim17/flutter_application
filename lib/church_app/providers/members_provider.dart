import 'package:flutter_application/church_app/models/church_member_directory_entry_model.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The church roster, live.
///
/// A one-shot read looked right and was wrong: the `display*` fields on a
/// membership row are a cache of `users/{uid}`, and the Cloud Function that
/// refreshes them runs *after* the person saves their profile. Editing your
/// own phone number and returning to Members showed the old one until the
/// app was restarted — the list had read the row a second before the server
/// rewrote it, and nothing told it to look again. Nothing can: the client
/// does not know when the fan-out lands, so it has to be listening.
final membersProvider = StreamProvider<List<ChurchMembership>>((ref) {
  final churchIdAsync = ref.watch(currentChurchIdProvider);
  final churchId = churchIdAsync.asData?.value;
  if (churchId == null) return const Stream<List<ChurchMembership>>.empty();

  final repo = MembersRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );

  return repo.watchMembers();
});

/// Reduced roster (name/photo/dob/gender/marital status only) any approved
/// member can read — used by the Members screen for a non-admin viewer,
/// which cannot read [membersProvider]'s full `members` docs for anyone but
/// themselves.
final memberDirectoryProvider =
    StreamProvider<List<ChurchMemberDirectoryEntry>>((ref) {
  final churchId = ref.watch(currentChurchIdProvider).asData?.value;
  if (churchId == null) {
    return const Stream<List<ChurchMemberDirectoryEntry>>.empty();
  }

  final repo = MembersRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );

  return repo.watchMemberDirectory();
});
