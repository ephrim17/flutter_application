import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PrayerNotificationService {
  PrayerNotificationService._();
  static final instance = PrayerNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _notificationId = 777;
  static const String _timeKey = "prayer_reminder_time";
  static const String _enabledKey = "prayer_reminder_enabled";

Future<void> init() async {
  tz.initializeTimeZones();

  final String currentTimeZone = DateTime.now().timeZoneName;

  try {
    tz.setLocalLocation(tz.getLocation(currentTimeZone));
  } catch (e) {
    // Fallback if timezone name doesn't match TZ database
    tz.setLocalLocation(tz.local);
  }

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();

  const settings = InitializationSettings(
    android: android,
    iOS: ios,
  );

  await _plugin.initialize(settings);
}

  // ================= PERMISSIONS =================

  Future<bool> requestPermissions(BuildContext context) async {
    if (Platform.isAndroid) {
      if (await Permission.notification.isDenied) {
        final result = await Permission.notification.request();
        if (!result.isGranted) {
          _showPermissionDialog(context);
          return false;
        }
      }

      // Android 12+ exact alarms
      if (!await Permission.scheduleExactAlarm.isGranted) {
        await Permission.scheduleExactAlarm.request();
      }
    }

    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      if (result != true) {
        _showPermissionDialog(context);
        return false;
      }
    }

    return true;
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Permission Required"),
        content: const Text(
            "Prayer reminders require notification permission."),
        actions: [
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text("Open Settings"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  // ================= SCHEDULE =================

  Future<void> scheduleDaily(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    //if (scheduled.isBefore(now)) {
      scheduled =  tz.TZDateTime.now(tz.local).add(const Duration(seconds: 15));
    //}
    print("Prayer notification scheduled at $scheduled");

    print("Local time: ${scheduled.toLocal()}");
print("Time zone: ${scheduled.location}");

    await _plugin.zonedSchedule(
      _notificationId,
      "Prayer Time 🙏",
      "Take a moment to pray and reflect.",
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_channel',
          'Prayer Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    await prefs.setBool(_enabledKey, true);
    await prefs.setString(
        _timeKey, "${time.hour}:${time.minute}");
  }

  Future<void> cancel() async {
    final prefs = await SharedPreferences.getInstance();
    await _plugin.cancel(_notificationId);
    await prefs.setBool(_enabledKey, false);
  }

  Future<TimeOfDay?> getSavedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_timeKey);

    if (stored == null) return null;

    final parts = stored.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }
}
