import 'package:flutter_application/church_app/screens/church_tab_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tab list is not a fixed length. An ordinary member has Home and For
/// You; a church admin also has Messages; Dashboard is conditional again on
/// top of that. Indices reach the shell from places that cannot see that
/// list — a notification payload, or the selection carried across a church
/// switch — so an index valid a moment ago can be out of range now.
///
/// Unchecked, that is a `RangeError` thrown from `screens[selectedIndex]`
/// while building, which surfaces as a red screen on tapping a notification
/// with nothing pointing at the code that chose the number.
void main() {
  group('an index this person actually has', () {
    test('is used unchanged', () {
      expect(safeTabIndex(0, 4), 0);
      expect(safeTabIndex(2, 4), 2);
      expect(safeTabIndex(3, 4), 3);
    });

    test('the last tab is in range, not off the end', () {
      expect(safeTabIndex(1, 2), 1);
    });
  });

  group('an index this person does not have', () {
    test('falls back to Home rather than the nearest tab', () {
      // A member with Home and For You who taps a feed notification asking
      // for tab 2. Clamping to the nearest would drop them on For You with
      // no explanation; Home is the obvious neutral answer.
      expect(safeTabIndex(2, 2), 0);
      expect(safeTabIndex(3, 2), 0);
      expect(safeTabIndex(99, 4), 0);
    });

    test('a negative index is Home, not a crash', () {
      expect(safeTabIndex(-1, 4), 0);
    });
  });

  group('degenerate input', () {
    test('no tabs at all yields 0 instead of dividing by nothing', () {
      expect(safeTabIndex(0, 0), 0);
      expect(safeTabIndex(3, 0), 0);
      expect(safeTabIndex(-2, 0), 0);
    });
  });

  group('the shapes the app actually builds', () {
    // Home, For You (+ Messages for an admin, + Dashboard when allowed).
    const memberTabs = 2;
    const adminTabs = 4;

    test('every notification tab index is safe for a plain member', () {
      // The indices `_handleNotificationKind` can set today.
      for (final requested in [0, 1]) {
        expect(safeTabIndex(requested, memberTabs), requested);
      }
    });

    test('and for an admin', () {
      for (final requested in [0, 1]) {
        expect(safeTabIndex(requested, adminTabs), requested);
      }
    });

    test('an admin index survives a switch to a church with fewer tabs', () {
      // Switching from a church you administer to one you do not: Dashboard
      // was selected, and that tab no longer exists.
      expect(safeTabIndex(3, memberTabs), 0);
    });
  });
}
