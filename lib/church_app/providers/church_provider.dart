import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Returns currently selected churchId
Future<String?> getCurrentChurchId() async {
  final storage = ChurchLocalStorage();
  final savedChurch = await storage.getChurch();
  return savedChurch?['id'] ?? 'tnbm';
}

final currentChurchIdProvider = FutureProvider<String?>((ref) async {
  final selectedChurch = ref.watch(selectedChurchProvider);
  if (selectedChurch != null) {
    return selectedChurch.id;
  }

  return getCurrentChurchId();
});
