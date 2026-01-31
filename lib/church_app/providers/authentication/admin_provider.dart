import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final isAdminProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(getCurrentUserProvider);
  final configAsync = ref.watch(appConfigProvider);

  return userAsync.maybeWhen(
    data: (user) =>
        user != null &&
        configAsync.value?.isAdmin(user.email) == true,
    orElse: () => false,
  );
});