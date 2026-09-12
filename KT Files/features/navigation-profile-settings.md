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
- The bottom tab bar's individual tabs float directly on the page background
  — there is no surrounding solid card/pill behind them, only the selected
  tab's own highlight.
- Bottom tabs preserve the selected index while the shell is alive.
- Dashboard exists only when the current user is a church admin and the feature
  is enabled.
- Drawer items are filtered by role and feature flags.
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
