import 'package:flutter_application/church_app/helpers/install_guide.dart';
import 'package:flutter_application/church_app/models/text_content_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

/// Installing a web app is the one thing every browser does differently and
/// none of them explain. Wrong steps are worse than no steps — "tap Share"
/// on a desktop, or "use the address bar install icon" in Safari, reads as
/// the app being broken — so the detection is pinned to real user agents.
void main() {
  group('iPhone and iPad', () {
    const safari =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';
    const chrome =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) CriOS/126.0.6478.108 Mobile/15E148 Safari/604.1';
    const firefox =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) FxiOS/127.0 Mobile/15E148 Safari/605.1.15';

    test('Safari gets the share-sheet steps', () {
      expect(installGuideForUserAgent(safari), InstallGuide.iosShareSheet);
    });

    test('Chrome on iOS is Safari underneath, so the same steps', () {
      expect(installGuideForUserAgent(chrome), InstallGuide.iosShareSheet);
    });

    test('Firefox on iOS cannot do it, so it is sent to Safari', () {
      expect(installGuideForUserAgent(firefox), InstallGuide.iosOtherBrowser);
    });

    test('an iPad reporting itself as a Mac is still iOS', () {
      expect(
        installGuideForUserAgent(
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
          '(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        ),
        InstallGuide.iosShareSheet,
      );
    });
  });

  group('Android', () {
    test('Chrome gets the menu steps', () {
      expect(
        installGuideForUserAgent(
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
        ),
        InstallGuide.androidChromium,
      );
    });

    test('Samsung Internet is Chromium too', () {
      expect(
        installGuideForUserAgent(
          'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 '
          '(KHTML, like Gecko) SamsungBrowser/23.0 Chrome/115.0.0.0 Mobile Safari/537.36',
        ),
        InstallGuide.androidChromium,
      );
    });

    test('Firefox has its own wording', () {
      expect(
        installGuideForUserAgent(
          'Mozilla/5.0 (Android 14; Mobile; rv:127.0) Gecko/127.0 Firefox/127.0',
        ),
        InstallGuide.androidFirefox,
      );
    });
  });

  group('desktop', () {
    test('Chrome', () {
      expect(
        installGuideForUserAgent(
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        ),
        InstallGuide.desktopChromium,
      );
    });

    test('Edge, which also calls itself Chrome', () {
      expect(
        installGuideForUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.2592.68',
        ),
        InstallGuide.desktopChromium,
      );
    });

    test('Safari, which every one of them borrows the name of', () {
      expect(
        installGuideForUserAgent(
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
          '(KHTML, like Gecko) Version/17.5 Safari/605.1.15',
        ),
        InstallGuide.desktopSafari,
      );
    });

    test('Firefox, which cannot install at all', () {
      expect(
        installGuideForUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:127.0) Gecko/20100101 Firefox/127.0',
        ),
        InstallGuide.desktopFirefox,
      );
    });
  });

  test('an unknown or empty agent falls back rather than guessing', () {
    expect(installGuideForUserAgent(''), InstallGuide.unknown);
    expect(installGuideForUserAgent('SomeKiosk/1.0'), InstallGuide.unknown);
  });

  group('every guide has text to show', () {
    for (final guide in InstallGuide.values) {
      test('${guide.name} has a title and all of its steps', () {
        expect(
          defaultChurchTextContents[installGuideTitleKey(guide)],
          isNotNull,
          reason: 'a guide with no heading renders a raw key',
        );
        for (var step = 1; step <= installGuideStepCount(guide); step++) {
          expect(
            defaultChurchTextContents[installGuideStepKey(guide, step)],
            isNotNull,
            reason: 'step $step of ${guide.name} has no text',
          );
        }
      });
    }
  });

  group('when to offer it at all', () {
    test('a browser that has not been told no', () {
      expect(
        shouldOfferAppInstall(
          isWeb: true,
          alreadyInstalled: false,
          dismissed: false,
        ),
        isTrue,
      );
    });

    test('never on a phone build — the app is the app', () {
      expect(
        shouldOfferAppInstall(
          isWeb: false,
          alreadyInstalled: false,
          dismissed: false,
        ),
        isFalse,
      );
    });

    test('never once it is already installed', () {
      expect(
        shouldOfferAppInstall(
          isWeb: true,
          alreadyInstalled: true,
          dismissed: false,
        ),
        isFalse,
      );
    });

    test('and "not now" means not again', () {
      expect(
        shouldOfferAppInstall(
          isWeb: true,
          alreadyInstalled: false,
          dismissed: true,
        ),
        isFalse,
      );
    });
  });
}
