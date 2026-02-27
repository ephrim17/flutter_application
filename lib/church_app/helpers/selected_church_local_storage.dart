import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChurchLocalStorage {
  static const _churchKey = 'selected_church';

  Future<void> saveChurch({
    required String id,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final data = jsonEncode({
      'id': id,
      'name': name,
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
}