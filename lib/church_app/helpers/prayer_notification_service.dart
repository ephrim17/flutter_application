import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/text_content_defaults.dart';
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
    if (kIsWeb) return;
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
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      if (await Permission.notification.isDenied) {
        final result = await Permission.notification.request();
        if (!result.isGranted) {
          if (!context.mounted) return false;
          _showPermissionDialog(context);
          return false;
        }
      }
    }

    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      if (result != true) {
        if (!context.mounted) return false;
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
        title: Text(context.t('ui.prayer_notification.permission_required')),
        content: Text(context.t(
            'ui.prayer_notification.prayer_reminders_require_notification_permission')),
        actions: [
          TextButton(
            onPressed: () => openAppSettings(),
            child: Text(context.t('ui.prayer_notification.open_settings')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('ui.prayer_notification.cancel')),
          ),
        ],
      ),
    );
  }

  // ================= SCHEDULE =================

  Future<void> scheduleDaily(TimeOfDay time) async {
    if (kIsWeb) {
      throw UnsupportedError(
        defaultChurchTextContents['prayer.reminders_not_supported']!,
      );
    }
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

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_channel',
        defaultChurchTextContents['prayer.reminder_channel']!,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      _notificationId,
      defaultChurchTextContents['prayer.reminder_title']!,
      defaultChurchTextContents['prayer.reminder_body']!,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_timeKey, "${time.hour}:${time.minute}");
  }

  Future<void> cancel() async {
    final prefs = await SharedPreferences.getInstance();
    if (!kIsWeb) await _plugin.cancel(_notificationId);
    await prefs.setBool(_enabledKey, false);
  }

  Future<TimeOfDay?> getSavedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_timeKey);

    if (stored == null) return null;

    final parts = stored.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return TimeOfDay(
      hour: hour,
      minute: minute,
    );
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }
}
