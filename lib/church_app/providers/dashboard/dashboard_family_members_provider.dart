import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/dashboard_member_metrics_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardFamilyMembersProvider =
    FutureProvider.family<List<AppUser>, DashboardFamilyBucket>((
  ref,
  familyBucket,
) async {
  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null || familyBucket.familyIds.isEmpty) {
    return const <AppUser>[];
  }

  final repo = MembersRepository(
    firestore: ref.read(firestoreProvider),
    churchId: churchId,
  );
  return repo.getMembersByFamilyIds(familyBucket.familyIds);
});
