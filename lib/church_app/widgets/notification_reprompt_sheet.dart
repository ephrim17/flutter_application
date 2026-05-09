import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';

Future<bool?>? _activeNotificationPermissionSheet;

Future<bool?> showNotificationPermissionSheet(
  BuildContext context,
) {
  if (kIsWeb) {
    return Future.value(false);
  }

  final activeSheet = _activeNotificationPermissionSheet;
  if (activeSheet != null) {
    return activeSheet;
  }

  final sheet = showAppModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent, // for rounded corners
    heightFactor: 0.4,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          72,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text(
              'Stay Updated 🔔',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enable notifications to receive updates about approvals and church announcements.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                    child: Text(
                      context.t(
                        'notifications.not_now',
                        fallback: 'Not now',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                    child: Text(
                      context.t(
                        'notifications.enable',
                        fallback: 'Enable',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  _activeNotificationPermissionSheet = sheet.whenComplete(() {
    _activeNotificationPermissionSheet = null;
  });
  return _activeNotificationPermissionSheet!;
}
