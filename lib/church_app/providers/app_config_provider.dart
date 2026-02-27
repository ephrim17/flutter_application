import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/app_config_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream provider
final appConfigProvider = StreamProvider<AppConfig>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final churchIdAsync = ref.watch(currentChurchIdProvider);

  return churchIdAsync.when(
    data: (churchId) {
      if (churchId == null) {
        return const Stream.empty();
      }

      final repo = AppConfigRepository(
        firestore: firestore,
        churchId: churchId,
      );

      return repo.watchAppConfig();
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});