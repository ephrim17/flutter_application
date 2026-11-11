import 'package:flutter_application/church_app/widgets/church_desktop_sidebar.dart';
import 'package:flutter_test/flutter_test.dart';

/// The desktop shell replaces the bottom tab bar with a sidebar and opens
/// the drawer permanently. That is right for a mouse and wrong for a thumb,
/// so where the line falls matters: a tablet in landscape must keep the
/// touch layout it already has.
void main() {
  group('phones and tablets keep the touch layout', () {
    test('phones', () {
      expect(useDesktopShell(320), isFalse);
      expect(useDesktopShell(360), isFalse);
      expect(useDesktopShell(393), isFalse); // iPhone 16
      expect(useDesktopShell(430), isFalse); // iPhone Pro Max
    });

    test('tablets, including landscape', () {
      expect(useDesktopShell(768), isFalse); // iPad portrait
      expect(useDesktopShell(834), isFalse); // iPad Air portrait
      expect(useDesktopShell(1024), isFalse); // iPad landscape
      expect(useDesktopShell(1194), isFalse); // iPad Pro 11" landscape
    });

    test('a small desktop window is still a touch-sized window', () {
      // Someone with a browser taking up half a laptop screen gets the
      // layout that fits the width they actually gave the app.
      expect(useDesktopShell(1000), isFalse);
      expect(useDesktopShell(1279), isFalse);
    });
  });

  group('desktop widths get the sidebar', () {
    test('at the breakpoint exactly', () {
      expect(useDesktopShell(desktopShellBreakpoint), isTrue);
      expect(useDesktopShell(1280), isTrue);
    });

    test('and above it', () {
      expect(useDesktopShell(1366), isTrue); // 12.9" iPad landscape, laptops
      expect(useDesktopShell(1440), isTrue);
      expect(useDesktopShell(1920), isTrue);
      expect(useDesktopShell(2560), isTrue);
    });
  });

  test('the sidebar leaves the content most of the window', () {
    // A sidebar that eats a third of a 1280 window would be worse than the
    // bottom bar it replaced.
    expect(desktopSidebarWidth / desktopShellBreakpoint, lessThan(0.25));
  });
}
