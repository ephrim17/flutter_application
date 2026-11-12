/// The glue defined in `web/index.html`.
///
/// It has to live there rather than here: `beforeinstallprompt` fires once,
/// early, long before Flutter has booted, and a browser only lets you show
/// the install prompt from the event object it handed you. The page catches
/// that event and keeps it; this reads what the page caught.
///
/// Every call is wrapped, because a browser with no install support — or a
/// page served from an older `index.html` that predates this glue — has to
/// come out as "cannot install" rather than as a crash.
library;

import 'dart:js_interop';

@JS('churchTreeInstallAvailable')
external bool _available();

@JS('churchTreeInstalled')
external bool _installed();

@JS('churchTreeUserAgent')
external String _userAgent();

@JS('churchTreeInstallPrompt')
external JSPromise<JSString> _prompt();

bool runningAsInstalledAppImpl() {
  try {
    return _installed();
  } catch (_) {
    return false;
  }
}

bool installPromptAvailableImpl() {
  try {
    return _available();
  } catch (_) {
    return false;
  }
}

/// Shows the browser's own install prompt, where there is one.
///
/// Returns what the reader chose: `accepted`, `dismissed`, or `unavailable`
/// when this browser never offered a prompt to show.
Future<String> requestInstallImpl() async {
  try {
    final outcome = await _prompt().toDart;
    return outcome.toDart;
  } catch (_) {
    return 'unavailable';
  }
}

String browserUserAgentImpl() {
  try {
    return _userAgent();
  } catch (_) {
    return '';
  }
}
