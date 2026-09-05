# Android App Stability — 2026-08-14

## Decision

**GO for the tested Android app-wide flows, with the explicit exclusions below.**

This decision covers application stability and the enabled experiences in The
New Beginning Ministries. It does not close Play Store, Firebase security,
external-delivery, or broad device-matrix release gates.

## Candidate and environment

| Field | Value |
|---|---|
| App version | `1.0.0+1` |
| Artifact | `build/app/outputs/flutter-apk/app-release.apk` |
| Artifact size | 113 MB |
| Package | `com.example.flutter_application` |
| Device | Android API 36 arm64 emulator, 1080 × 2400 |
| Role | Church admin |
| Church | The New Beginning Ministries |

## Automated results

- `flutter analyze lib/church_app test`: no issues.
- `flutter test`: 59 tests passed.
- `flutter build apk --release`: passed.
- Release APK upgrade installation and relaunch: passed.
- App-process log scan after relaunch: no Flutter exception, fatal exception,
  render overflow, invalid animation value, or disposed-provider error.

## End-to-end coverage

- Entry: clean login, persisted session, church chooser, church selection,
  release relaunch, and background/resume.
- Member shell: Home, For You, Feed, Go Further, Dashboard, drawer navigation,
  announcement prompt, and all enabled entry points.
- Feed: validation, create, search, edit, persistence, and delete using a
  QA-prefixed record.
- Circle: create response, persistence, and delete using a QA-prefixed response.
- Prayer requests: validation, create, edit, expiry display, and delete using a
  QA-prefixed request.
- Equipment: validation, create, edit, persistence, delete, inventory summary,
  categories, conditions, locations, and initial already-loaded stream state.
- Members: All, Families, Individuals, and Special Day tabs; counts, list,
  create-flow choice, and required-name validation.
- Church Groups: current group, member list, and full ten-group picker.
- Favorites: empty state.
- Holy Bible: catalogue and progressive offline download.
- About: multilingual church profile and scrollable content.
- Settings: profile entry, theme toggle and restoration, notification-blocked
  state, prayer-reminder control, and feedback entry point.
- Studio: complete feature inventory rendered for branding, content, faith
  engagement, live configuration, sections, notifications, important prompt,
  admin mode, and admin management.
- Dashboard: all summary panels and source data rendered.
- Super-admin: safe read-only dashboard and learning-result navigation were
  smoke-tested; no global mutation was performed.

All QA-created feed, Circle, prayer, and equipment records were removed after
verification.

## Defects fixed

1. Login account creation could read Riverpod state after the screen was
   disposed. Async completion now checks lifecycle state and uses a captured
   loading notifier; a regression test covers the invariant.
2. Equipment opened with zero totals when its provider had loaded before the
   view model was created. Initial state now seeds from the current provider
   snapshot; the rebuilt APK immediately shows the three existing records.
3. Prayer requests expiring tomorrow could incorrectly say they ended today.
   Remaining time now compares normalized calendar dates and is unit-tested at
   the late-day boundary.
4. Dashboard streak copy used plural grammar for one member. Singular and plural
   defaults are now selected correctly.
5. The feed create floating action button lacked an accessibility label. It now
   exposes the localized create label.
6. The English member-since label contained an accidental `CCC` suffix. The
   default and policy regression test are corrected.

## Explicitly excluded or partially covered

- Play Console, signing identity, store listing, app bundle, and policy checks.
- Firebase rules, indexes, deployed Functions, production authorization, and
  cross-church negative-permission testing.
- Actual notification broadcast, email delivery, password-reset email, live
  YouTube delivery, and notification deep links from all process states.
- Destructive global/church configuration mutations, admin-mode activation,
  member deletion, and account deletion.
- Physical-device, API 24/29/33, low-memory, offline/poor-network, rotation,
  large-text, and translated-layout matrix.
- The Bible offline package was observed progressing successfully but was not
  used as a release blocker while the remaining files continued downloading.

These exclusions mean this is an app-stability go, not an unconditional public
production-release approval.
