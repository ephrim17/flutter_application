import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A stable per-install id, generated once and persisted locally. Used to
/// key `users/{uid}/devices/{installationId}` (§4.1/Phase 5) — distinct
/// from the FCM token itself, which can rotate.
Future<String> getDeviceInstallationId() async {
  const key = 'device_installation_id';
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(key);
  if (existing != null && existing.isNotEmpty) return existing;

  final generated = const Uuid().v4();
  await prefs.setString(key, generated);
  return generated;
}
