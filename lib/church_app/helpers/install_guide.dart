/// Which set of "add this to your home screen" instructions a browser needs.
///
/// Installing a web app is the one thing every browser does differently and
/// none of them explain: Chrome hides it behind a menu, Safari behind the
/// share sheet, and Firefox on a desktop does not do it at all. Guessing
/// wrong is worse than saying nothing, so the steps are chosen from the
/// user agent rather than written once for "the browser".
enum InstallGuide {
  /// Chrome, Edge, Samsung Internet and friends on Android. These also fire
  /// `beforeinstallprompt`, so the button usually does the work.
  androidChromium,

  /// Firefox on Android: an "Install" item in the menu, no prompt event.
  androidFirefox,

  /// Safari on iPhone or iPad, and the browsers there that share its
  /// share-sheet flow (Chrome and Edge on iOS are Safari underneath).
  iosShareSheet,

  /// An iOS browser without "Add to Home Screen" of its own. The page has
  /// to be opened in Safari first.
  iosOtherBrowser,

  /// Chrome, Edge, Brave or Opera on a desktop: an install icon lives at
  /// the right-hand end of the address bar.
  desktopChromium,

  /// Safari on macOS Sonoma or later: File → Add to Dock.
  desktopSafari,

  /// Desktop Firefox cannot install a web app at all. Saying so, and what
  /// to do instead, beats steps that lead nowhere.
  desktopFirefox,

  /// Anything we cannot place. Generic wording that points at the menu.
  unknown,
}

/// Picks the instructions from a browser's user agent string.
///
/// Order matters: the iOS checks come first because Chrome and Edge there
/// also say "Safari", and the Chromium checks come after Edge and Opera for
/// the same reason — every one of them claims to be Chrome.
InstallGuide installGuideForUserAgent(String userAgent) {
  final ua = userAgent.toLowerCase();
  if (ua.isEmpty) return InstallGuide.unknown;

  final isIos = ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod') ||
      // iPadOS 13+ reports itself as a Mac; the touch hint is what gives it
      // away in the agent string browsers still send.
      (ua.contains('macintosh') && ua.contains('mobile'));

  if (isIos) {
    // Firefox on iOS has no "Add to Home Screen" of its own.
    if (ua.contains('fxios')) return InstallGuide.iosOtherBrowser;
    return InstallGuide.iosShareSheet;
  }

  if (ua.contains('android')) {
    if (ua.contains('firefox') || ua.contains('fxios')) {
      return InstallGuide.androidFirefox;
    }
    return InstallGuide.androidChromium;
  }

  if (ua.contains('firefox')) return InstallGuide.desktopFirefox;

  if (ua.contains('edg') ||
      ua.contains('opr') ||
      ua.contains('chrome') ||
      ua.contains('chromium')) {
    return InstallGuide.desktopChromium;
  }

  // Safari identifies itself last, after every browser that borrows its
  // name, so this is only reached by the real one.
  if (ua.contains('safari')) return InstallGuide.desktopSafari;

  return InstallGuide.unknown;
}

/// How many numbered steps a guide has. The text itself lives in the church
/// text contents under `install.steps.<guide>.<n>`, so a church can reword
/// it like everything else.
int installGuideStepCount(InstallGuide guide) {
  switch (guide) {
    case InstallGuide.desktopFirefox:
    case InstallGuide.unknown:
      return 2;
    case InstallGuide.androidChromium:
    case InstallGuide.androidFirefox:
    case InstallGuide.iosShareSheet:
    case InstallGuide.iosOtherBrowser:
    case InstallGuide.desktopChromium:
    case InstallGuide.desktopSafari:
      return 3;
  }
}

/// The text key for one step of a guide, counted from 1.
String installGuideStepKey(InstallGuide guide, int step) =>
    'install.steps.${guide.name}.$step';

/// The text key for a guide's own one-line heading.
String installGuideTitleKey(InstallGuide guide) =>
    'install.steps.${guide.name}.title';

/// Whether to offer the "add it to your home screen" banner at all.
///
/// Three separate reasons not to: this is not a browser, the app is already
/// installed and running from the home screen, or the reader has said no.
bool shouldOfferAppInstall({
  required bool isWeb,
  required bool alreadyInstalled,
  required bool dismissed,
}) =>
    isWeb && !alreadyInstalled && !dismissed;
