import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const financeChurchGroupId = 'finance';

// §9.1: church admin authority is the signed-in email against
// config/app.admins, checked against the live Firebase Auth email — never
// against a stored profile field.
final isAdminProvider = Provider<bool>((ref) {
  final email =
      ref.watch(firebaseAuthProvider).currentUser?.email?.trim() ?? '';
  if (email.isEmpty) return false;

  final config = ref.watch(appConfigProvider).value;
  if (config == null) return false;

  return config.isAdmin(email);
});

final churchAdminProvider = Provider.family<bool, String>((ref, churchId) {
  final email =
      ref.watch(firebaseAuthProvider).currentUser?.email?.trim() ?? '';
  if (email.isEmpty || churchId.trim().isEmpty) {
    return false;
  }

  final configAsync = ref.watch(churchAppConfigProvider(churchId));
  final config = configAsync.value;
  if (config == null) {
    return false;
  }

  return config.isAdmin(email);
});

final financeDashboardAccessProvider = Provider<bool>((ref) {
  final membershipAsync = ref.watch(currentMembershipProvider);

  return membershipAsync.maybeWhen(
    data: (membership) {
      if (membership == null) return false;
      return membership.churchGroupIds
          .map((item) => item.trim().toLowerCase())
          .contains(financeChurchGroupId);
    },
    orElse: () => false,
  );
});
