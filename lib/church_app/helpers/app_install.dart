import 'package:flutter/foundation.dart';

import 'app_install_stub.dart' if (dart.library.html) 'app_install_web.dart'
    as platform;

/// Is the page already running as an installed app — from the home screen,
/// the dock or its own window — rather than in a browser tab?
bool isRunningAsInstalledApp() =>
    kIsWeb && platform.runningAsInstalledAppImpl();

/// Has the browser offered an install prompt we are allowed to show?
///
/// Chromium browsers do; Safari and Firefox never do, and there the written
/// steps are the whole answer.
bool isInstallPromptAvailable() =>
    kIsWeb && platform.installPromptAvailableImpl();

/// Shows the browser's own install prompt. `accepted`, `dismissed` or
/// `unavailable`.
Future<String> requestAppInstall() async {
  if (!kIsWeb) return 'unavailable';
  return platform.requestInstallImpl();
}

/// The browser's user agent, for picking which instructions to show.
String currentBrowserUserAgent() =>
    kIsWeb ? platform.browserUserAgentImpl() : '';
