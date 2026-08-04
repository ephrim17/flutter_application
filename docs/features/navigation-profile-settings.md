# Navigation, Profile and Settings

## Scope

The authenticated shell provides Home, For You, Feeds and Go Further tabs,
plus an admin-only Dashboard when enabled. The drawer exposes permitted
features and compact counts. Settings owns profile, appearance, notifications,
prayer reminders, feedback, local-data clearing and logout.

## Behaviour

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
- Dark mode persists locally. Push permission reflects operating-system state.
- Prayer reminders schedule or cancel local notifications.
- Feedback is written for super-admin review.
- Clearing local data removes local preferences/cache but not server records.
- Logout unsubscribes/clears the active session and returns to entry.

## Technical map

- Shell: `church_tab_screen.dart`, `widgets/app_bottom_tab_bar.dart`.
- Drawer: `church_side_drawer.dart`, `helpers/drawer_constants.dart`.
- Settings: `screens/side_drawer/settings_screen.dart`.
- Avatar: `widgets/app_profile_avatar.dart`.
- Notification setup: `services/notification_service.dart`.
- Feedback: `globalFeedback` through the settings/super-admin providers.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| NAV-01 | Tap each bottom tab repeatedly | Correct screen opens once; no state/index crash. |
| NAV-02 | Member vs admin shell | Member cannot see Dashboard/Studio/Equipment; eligible admin can. |
| NAV-03 | Disable a feature remotely | Matching tab/drawer item disappears safely. |
| NAV-04 | Badge data loading/error/success | No misleading zero while loading; final compact number is correct. |
| SETTINGS-01 | Add/change/remove profile photo | Avatar updates across drawer, feeds, articles, circles and quick cards. |
| SETTINGS-02 | Save valid/invalid profile | Valid values persist; validation prevents malformed phone/location/date. |
| SETTINGS-03 | Toggle dark mode and relaunch | Theme persists without unreadable controls. |
| SETTINGS-04 | Enable/deny push permission | Status and action match OS settings; denial does not loop prompts. |
| SETTINGS-05 | Add/edit/remove reminder | Local notification schedule matches chosen time. |
| SETTINGS-06 | Submit feedback | One feedback record appears for super admin; double-submit is prevented. |
| SETTINGS-07 | Clear local data | Confirmation appears; server profile/content remains intact. |
| SETTINGS-08 | Logout and sign in again | No previous-church content flashes before re-resolution. |
| NAV-05 | Large text/small phone | Labels, badges and settings sheets do not overflow. |

