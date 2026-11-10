import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChurchLocalStorage {
  static const _churchKey = 'selected_church';
  static const _churchTopicKey = 'selected_church_topic';
  static const _notificationTopicsKey = 'subscribed_notification_topics';

  Future<void> saveChurch({
    required String id,
    required String name,
    String logo = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final data = jsonEncode({
      'id': id,
      'name': name,
      'logo': logo,
    });

    await prefs.setString(_churchKey, data);
  }

  Future<Map<String, dynamic>?> getChurch() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_churchKey);

    if (data == null) return null;

    return jsonDecode(data);
  }

  Future<void> clearChurch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_churchKey);
  }

  Future<void> saveSubscribedChurchTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_churchTopicKey, topic);
  }

  Future<String?> getSubscribedChurchTopic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_churchTopicKey);
  }

  /// Kept for sign-out and account-switch paths. Nothing subscribes to FCM
  /// topics any more — the server addresses devices from church membership —
  /// so these only clear what older installs left behind.
  Future<void> clearSubscribedChurchTopic() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_churchTopicKey);
  }

  Future<void> clearSubscribedNotificationTopics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationTopicsKey);
    await prefs.remove(_churchTopicKey);
  }
}
