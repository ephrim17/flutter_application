import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Returns currently selected churchId
Future<String?> getCurrentChurchId() async {
  final storage = ChurchLocalStorage();
  final savedChurch = await storage.getChurch();
  return savedChurch?['id'];
}

final currentChurchIdProvider = FutureProvider<String?>((ref) async {
  return getCurrentChurchId();
});