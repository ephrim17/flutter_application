import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const financeChurchGroupId = 'finance';

final isAdminProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(getCurrentUserProvider);
  final configAsync = ref.watch(appConfigProvider);

  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return false;

      final config = configAsync.value;
      if (config == null) return false;

      final result = config.isAdmin(user.email);

      return result;
    },
    orElse: () => false,
  );
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
  final userAsync = ref.watch(appUserProvider);

  return userAsync.maybeWhen(
    data: (user) {
      if (user == null) return false;
      return user.churchGroupIds
          .map((item) => item.trim().toLowerCase())
          .contains(financeChurchGroupId);
    },
    orElse: () => false,
  );
});
