import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Returns currently selected churchId
Future<String?> getCurrentChurchId() async {
  final storage = ChurchLocalStorage();
  final savedChurch = await storage.getChurch();
  return savedChurch?['id'];
}

/// The church every church-scoped provider resolves against — most
/// importantly `appConfigProvider` -> `textContentProvider`, which every
/// `context.t()`/`ref.t()` call in the app depends on, so this runs
/// continuously regardless of which screen is showing.
///
/// `selectedChurchProvider` (set only for an approved membership — see
/// `AppEntry._resolvableChurchId`) is trusted immediately. The local-storage
/// fallback below is NOT similarly trustworthy on its own: nothing clears
/// it except an explicit logout/delete-account, so it can point at a church
/// the signed-in user was never approved for at all (e.g. a different
/// account's leftover session on the same device — signing into a new
/// account by any path other than the app's own logout button does not
/// clear it). Streaming church-scoped data for that church would otherwise
/// throw `PERMISSION_DENIED` continuously, since `firestore.rules` denies
/// it — this is the client-side twin of the "unconditional
/// selectedChurchProvider" bug class documented in the migration doc's
/// addenda; same mistake, different provider. Cross-checking against
/// `myMembershipsProvider` before trusting it closes this the same way.
final currentChurchIdProvider = FutureProvider<String?>((ref) async {
  final selectedChurch = ref.watch(selectedChurchProvider);
  if (selectedChurch != null) {
    return selectedChurch.id;
  }

  final localChurchId = await getCurrentChurchId();
  if (localChurchId == null) return null;

  final memberships = await ref.watch(myMembershipsProvider.future);
  final isApproved = memberships.any(
    (membership) => membership.churchId == localChurchId && membership.approved,
  );
  return isApproved ? localChurchId : null;
});
