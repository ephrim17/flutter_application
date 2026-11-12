# Navigation, Profile and Settings

## Scope

The authenticated shell provides Home, For You and Community tabs, plus an
admin-only Dashboard when enabled. The standalone Discover tab was removed —
browsing other churches now happens from the "Your churches"/"Other
churches" lists on the church-selection screen (see
[Churches and Membership](churches-and-membership.md)), which reuses the same
church card design Discover used to show. The drawer exposes permitted
features and compact counts. Settings owns profile, appearance, notifications,
prayer reminders, feedback, local-data clearing, logout, and — for a church's
own admin — that church's public profile (pastor, contact details, social
links).

## Behaviour

- The shell's app bar shows the app's own "Church Tree" brand (logo + name),
  not the selected church's identity — the church switcher (that church's
  logo + a chevron) lives in a right-side action button instead, opening the
  same `ChurchQuickSwitcherSheet`.
- The app bar stands at `kToolbarHeight` (56), the Material standard. It
  previously hard-coded 40, which is shorter than the 48dp minimum touch
  target, so both the drawer button and the church switcher were undersized
  and the bar read as a cramped strip rather than a navigation bar. The
  switcher's tap target is held at a minimum of 48×48 regardless of the
  artwork inside it.
## Desktop shell

Past `desktopShellBreakpoint` (1280) the shell rearranges itself for a mouse
and a wide window. The phone layout is right for a phone and a tablet and
wrong for a desktop: a top app bar across 1,600px, a bottom tab bar whose
selected pill stretched to a third of the screen, and a drawer hidden behind
a hamburger with room to spare beside it.

- Destinations move from the bottom of the screen into a permanent 268pt
  sidebar (`ChurchDesktopSidebar`), as rows with icon and label.
- The drawer stops sliding over the page and sits in that sidebar beneath
  them, scrolling on its own while the destinations stay put.
- The top app bar goes entirely; the brand and the church switcher move to
  the top of the sidebar, where the switcher can show the church's **name**
  rather than only a logo and a chevron.

The sidebar renders the identical `AppBottomTabItem` list the bottom bar
does and embeds the very same `AppDrawer`, so a tab or a menu entry added
for the phone cannot go missing on desktop.

`AppDrawer.embedded` exists for this. It drops the `Drawer` shell, which
would impose its own surface and fixed 304 width inside a column that
already has both, and it stops `_handleTap` popping the route — there is no
drawer to close when it is permanent, so that pop would take the current
page off the stack instead.

The breakpoint sits above a tablet in landscape deliberately: an iPad is
about 1180–1194 points and wants the touch layout, where a bottom bar falls
under the thumb and a sidebar does not. A 12.9" iPad (1366) crosses the
line, which is a judgement call at that size. `safeTabIndex` guards the
shell against an index that no longer exists — a notification payload or a
selection carried across a church switch can both name a tab this person
does not have.

### Content width on a desktop

Two different rules, on purpose:

- **Home and For You have no cap.** They are cards and pictures, and they
  look right filling whatever window they are given. This was asked for
  explicitly and must not be "tidied" into a column.
- **Lists, forms and tables cap at `desktopReadableWidth` (1100)** via
  `DesktopContentWidth`. A member row whose name sits at the far left and
  whose toggle sits 1,400px away at the far right is not using the width,
  it is making the eye travel for nothing and inviting a tap on the wrong
  row. Applied to Attendance, Members (body *and* its search/tab header, or
  they disagree with each other), Church Groups, Settings and Studio.

Below 1100 `DesktopContentWidth` does nothing at all — no centring, no
padding — so phones and tablets keep exactly the layout they had.

Grids of small stat tiles choose their column count from the available
width (`statGridColumns`, 2/3/4) with a fixed tile height rather than an
aspect ratio. Attendance had `crossAxisCount: 2` at a 1.75 ratio, which on
a 1,568px window gave each tile about 770 by 440 — an enormous box around
the word "16".

- The bottom tab bar's individual tabs float directly on the page background
  — there is no surrounding solid card/pill behind them, only the selected
  tab's own highlight.
- Bottom tabs preserve the selected index while the shell is alive.
- Dashboard exists only when the current user is a church admin and the feature
  is enabled.
- Drawer items are filtered by role and feature flags.
- Both `AppDrawer` (full shell) and `GuestSideDrawer` (guest shell) show the
  signed-in user's profile avatar (photo, or initials if none) above their
  name/email in the header — a plain `Container` sized to its content, not
  Flutter's `DrawerHeader` (whose fixed default height was sized for the
  old name/email/chip-only content and overflowed once the avatar was
  added). `GuestSideDrawer`'s "Settings" item lives in the drawer itself
  (not a separate app bar icon like the full shell never had either) — see
  [Churches and Membership](churches-and-membership.md) for the
  `GuestSettingsScreen` it opens and the incomplete-profile badge on its
  icon.
- Favorites, prayer requests, members and equipment display a compact number at
  the end of the row when the count is available.
- Profile photo can be added, changed or removed and is reused through the
  common profile avatar wherever user identity is shown.
- Profile updates include supported contact/demographic fields and remain
  church/user scoped.
- When the user selects a marital status in Edit Profile, a family-ID section
  appears (mirrors the admin request-access form): a "Use existing family ID"
  toggle over a dropdown of the current church's existing families, or a
  Family Name field to generate a new one. Saving writes the global identity
  fields and, if the resolved family ID changed, updates
  `churches/{churchId}/members/{uid}.category`/`.familyId` for the
  currently-selected church via the same self-service write path member
  self-edits already use.
- Edit Profile is reachable from Settings → Profile, from a "Setup Profile"
  prompt on Home when the user's profile is incomplete, and from an account
  icon on the church-picker screen (see [Home](home.md) and
  [Churches and Membership](churches-and-membership.md)). The church-picker
  entry point opens `GuestSettingsScreen` instead of the full `SettingsScreen`
  — same file, same private section widgets, but only the church-agnostic
  sections (see Churches and Membership for the exact list).
- `users/{uid}.profileComplete` is derived, not a free-standing flag: every
  write path (Edit Profile save, and the self-signup/request-access identity
  sync) recomputes it as `location`, `address` and `maritalStatus` all
  non-empty, matching the definition the schema migration used. No write
  path may hardcode it to `true`.
- Dark mode persists locally. Push permission reflects operating-system state.
- Prayer reminders schedule or cancel local notifications.
- Feedback is written for super-admin review.
- Clearing local data removes local preferences/cache but not server records.
- Logout unsubscribes/clears the active session and returns to entry.
- Shared loading states use a native progress indicator that remains stable on
  Android and exposes localized loading semantics.
- Android status and navigation bar icons follow the active surface brightness
  so system controls remain legible in light and dark themes.

## Installing the web app

A browser tab says nothing about being keepable, and the browser's own
install hint is a one-line bar most people never see. So the offer is made
in the app, in words, with the steps for the browser the reader is actually
in.

- **`web/index.html` catches `beforeinstallprompt`** and keeps the event.
  It has to: the event fires once, early, usually before Flutter has
  booted, and a browser only lets you show the install prompt from the
  event object it handed you. The page calls `preventDefault()` on it, so
  the browser's own mini-infobar does not appear and the offer is made once,
  where it can be explained. It exposes `churchTreeInstallAvailable`,
  `churchTreeInstalled`, `churchTreeUserAgent` and `churchTreeInstallPrompt`
  as plain functions.
- **`helpers/app_install.dart`** is the Dart side, behind the usual
  stub/web conditional import, so a phone build neither sees nor compiles
  any of it. Every call is wrapped: a browser with no install support, or a
  page served from an older `index.html` that predates the glue, reads as
  "cannot install" rather than crashing.
- **`helpers/install_guide.dart`** picks the written steps from the user
  agent. Only Chromium browsers fire the prompt event; Safari and Firefox
  never do, and there the written steps are the whole answer, which is why
  they are not a footnote under a button. Order matters in the detection:
  the iOS checks come first because Chrome and Edge there are Safari
  underneath, and the Chromium checks come after Edge and Opera because
  every one of them claims to be Chrome. Desktop Firefox cannot install a
  web app at all, and is told so rather than given steps that lead nowhere.
- **Where it appears:** a dismissible banner at the top of Home
  (`widgets/app_install_banner.dart`) and a permanent entry in Settings →
  Preferences. The banner takes "Not now" for an answer permanently, per
  device (`app_install_banner_dismissed` in shared preferences) — which is
  exactly why Settings keeps an entry: a feature that lives only in a
  banner someone has waved away is a feature they cannot find again. The
  banner carries its own top gap, so on a phone build, where it draws
  nothing, it leaves no band of empty page behind it.
- Neither appears once the app is already running installed
  (`display-mode: standalone`), and the Settings tile then reads as done.

`test/install_guide_test.dart` pins the browser detection against real user
agent strings, that every guide has text for every step it claims, and the
three reasons not to offer this at all.

## Technical map

- Shell: `church_tab_screen.dart`, `widgets/app_bottom_tab_bar.dart`.
- Drawer: `church_side_drawer.dart`, `helpers/drawer_constants.dart`.
- Settings: `screens/side_drawer/settings_screen.dart`.
- Church profile editor (admin-only): `widgets/church_profile_editor_sheet.dart`.
- Avatar: `widgets/app_profile_avatar.dart`.
- Notification setup: `services/notification_service.dart`.
- Feedback: `globalFeedback` through the settings/super-admin providers.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| NAV-01 | Tap each bottom tab repeatedly | Correct screen opens once; no state/index crash. |
| NAV-01a | Open the shell, tap the right-side church action | App bar title reads "Church Tree" with its own logo; the action button opens the church switcher sheet unchanged. |
| NAV-01b | Open `AppDrawer` or `GuestSideDrawer` | Profile avatar (photo/initials) shows above name/email with no overflow, regardless of image load timing. |
| NAV-01c | Open `GuestSideDrawer`, tap Settings | Opens `GuestSettingsScreen`; the guest shell's app bar itself has no settings icon. |
| NAV-02 | Member vs admin shell | Member cannot see Dashboard/Studio/Equipment; eligible admin can. |
| NAV-03 | Disable a feature remotely | Matching tab/drawer item disappears safely. |
| NAV-08 | Switch between Highlights/Community inside For You, then back to Home/Community tab and return | Segment selection and each segment's scroll/pagination state survive the round trip. |
| NAV-04 | Badge data loading/error/success | No misleading zero while loading; final compact number is correct. |
| SETTINGS-01 | Add/change/remove profile photo | Avatar updates across drawer, feeds, articles, circles and quick cards. |
| SETTINGS-02 | Save valid/invalid profile | Valid values persist; validation prevents malformed phone/location/date. |
| SETTINGS-03 | Toggle dark mode and relaunch | Theme persists without unreadable controls. |
| SETTINGS-04 | Enable/deny push permission | Status and action match OS settings; denial does not loop prompts. |
| SETTINGS-05 | Add/edit/remove reminder | Local notification schedule matches chosen time. |
| SETTINGS-06 | Submit feedback | One feedback record appears for super admin; double-submit is prevented. |
| SETTINGS-07 | Clear local data | Confirmation appears; server profile/content remains intact. |
| SETTINGS-08 | Logout and sign in again | No previous-church content flashes before re-resolution. |
| SETTINGS-09 | Church admin edits church profile (pastor, contact, social links) from Settings | Section is hidden for non-admins and when no church is selected; save updates `churches/{churchId}` and refreshes Your/Other Churches and the church directory. |
| SETTINGS-10 | Set marital status to Married in Edit Profile, then toggle "Use existing family ID" on/off and save | Family section renders without overflow; saving with the toggle off creates/uses a new family ID from Family Name, with it on assigns the selected existing family ID; membership doc updates accordingly. |
| SETTINGS-11 | Save Edit Profile with location/address/maritalStatus still blank, then fill all three and save again | `profileComplete` stays `false` after the first save and only flips to `true` once all three are non-empty; Setup Profile prompts disappear live. |
| NAV-05 | Large text/small phone | Labels, membership dates, badges and settings sheets render cleanly without stray text or overflow. |
| NAV-06 | Open screens with initial or paginated loading states | Progress indicator renders without animation/runtime exceptions. |
| NAV-07 | Open light and dark screens on Android | Status/navigation icons contrast with the app surface. |
| NAV-08 | Open the app at 393x852 (iPhone 16) | The app bar is a full-height navigation bar, not a thin strip; the drawer button and church switcher are both comfortably tappable. |
| NAV-09 | Open the app in a browser window 1280 wide or more | A left sidebar carries brand, church switcher, destinations and the menu; there is no top app bar and no bottom tab bar. |
| NAV-10 | Drag that window below 1280 | The phone layout returns: app bar with hamburger, bottom tab bar, drawer slides over. Nothing is lost in either direction. |
| NAV-11 | Open an iPad in landscape (about 1194) | Still the touch layout, unchanged. |
| NAV-12 | Tap a menu entry in the desktop sidebar | It opens as a full page; the sidebar stays and the shell is not popped. |
| NAV-13 | Switch to a church where you are not an admin while Dashboard is selected | The shell falls back to Home rather than throwing a RangeError on a tab that no longer exists. |
| NAV-14 | Open Attendance on a desktop window | Four compact stat tiles in one row, not a 2x2 grid of large empty boxes. |
| NAV-15 | Open Members, Church Groups, Settings and Studio on a desktop window | Content sits in one readable column; trailing controls stay near the rows they belong to. |
| NAV-16 | Compare the Members search box with the list under it on desktop | Both are the same width; the search must not run the full window while the list is capped. |
| NAV-17 | Open the same screens on a phone and a tablet | Identical to before — the cap is inert below 1100. |
| NAV-18 | Open the site in Chrome on Android, Chrome on a desktop, Safari on iPhone, Safari on a Mac and Firefox | Home shows the install banner; opening it gives steps that match that browser, and only the Chromium ones also show a working Install button. |
| NAV-19 | Tap "Not now", then reload | The banner stays gone; Settings → Preferences → Add to home screen still opens the same instructions. |
| NAV-20 | Install the app, then open it from the home screen | No banner on Home; the Settings entry reads as already installed and is not tappable. |
| NAV-21 | Open the app on a phone build (Android/iOS) | No install banner and no Settings entry anywhere. |
