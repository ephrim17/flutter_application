# Android Release Readiness — 2026-08-13

## Decision

**NO-GO until the release identity, signing, Firebase authorization, account
deletion, and role-based device suites below are resolved.**

## Candidate

| Field | Value |
|---|---|
| Commit inspected | `cb5a22e` plus the working-tree fixes listed below |
| App version | `1.0.0+1` |
| Android artifact | `build/app/outputs/flutter-apk/app-release.apk` |
| Artifact size | 113 MB |
| Package | `com.example.flutter_application` |
| SDK | min 24, target/compile 36 |
| Devices | Two Android API 36 arm64 emulators, 1080 × 2400 and 1080 × 2424 |
| Firebase project | `flutterlearning-c9f6c` |

## Passed checks

- `flutter analyze lib/church_app test`: no issues.
- `flutter test`: 53 tests passed.
- Cloud Functions lint and TypeScript build passed.
- Release APK built and installed successfully on both API 36 emulators.
- Fresh-install onboarding reached all four pages and persisted completion.
- Registration entry rendered in light and dark system themes without overflow.
- Light/dark status and navigation icons retained visible contrast.
- App background/resume and release relaunch produced no app FATAL exception.
- All 20 deployed Cloud Functions report ACTIVE on Node.js 24.
- The latest 100 production Function log entries contained no error-severity
  entry; scheduled Live Church refresh and dashboard metric rebuild succeeded.

## Defects fixed during this pass

1. The shared dotLottie loader threw `Infinity or NaN toInt` repeatedly on the
   Android release runtime. It now uses a stable native progress indicator with
   localized semantics and widget regression coverage.
2. Transparent entry app bars selected white status icons on light surfaces.
   Global and app-bar overlay styles now use surface-aware icon brightness,
   verified on the release APK in light and dark modes.
3. Seven analyzer-only legacy warnings prevented the documented analyzer gate
   from passing. The intentional legacy exceptions are now scoped explicitly.

## Release blockers

| Severity | Blocker | Required closure |
|---|---|---|
| Blocker | Placeholder package `com.example.flutter_application` is also registered in `google-services.json`. | Confirm the permanent Play package, register that Android app in Firebase, replace Firebase config, namespace/application ID and Kotlin package. |
| Blocker | Release uses the debug signing key; no upload keystore/config exists. | Create or supply the permanent Play upload key and configure release signing outside source control. |
| Blocker | A new Play app must be uploaded as an Android App Bundle, not an APK. | Produce and validate a signed `.aab`; keep the APK only for direct device QA. |
| Blocker | No `firestore.rules` exists and `firebase.json` cannot deploy Firestore rules. | Export/review production rules, commit them, add the Firebase mapping and run emulator negative-permission tests. |
| Blocker | Local Storage rules allow every authenticated account to read/write arbitrary church paths, including equipment, feeds and Studio-owned assets. | Enforce membership, church-admin, super-admin and ownership checks; test cross-church denial before deployment. |
| Partially closed (2026-09-09) | Settings now has a working "Delete account" action (password re-entry, then a callable Cloud Function deletes users/{uid} + every membership/church/group row + Storage blobs + the Auth user — see `KT Files/architecture/user-church-decoupling-migration.md` Phase 7). **Not yet closed:** the function (`deleteAccount`) is written and passes lint/build but has not been deployed to production, so the UI path is untestable end-to-end until `npm --prefix functions run deploy` runs; also still fully open: Play Console privacy-policy and a public web deletion URL (Google requires the deletion path work without installing the app), neither of which exist in the repository. | Deploy the function, test the full flow against migrationv1 or a deployed backend, then agree and publish the privacy-policy/web-deletion-URL pair before submitting to Play Console. |
| Blocker | The 240 documented role/data scenarios cannot be executed without the standard non-production identities and two-church fixture. | Supply isolated member, pending, church-admin and super-admin test accounts plus Church A/B test data. |

## Play Console checks still requiring console evidence

- Store listing, privacy policy, Data safety and account-deletion declarations.
- Advertising ID declaration because the merged manifest contains `AD_ID`.
- Location disclosure/justification for coarse and fine location permissions.
- Notification permission and notification-content policy declarations.
- App access instructions for reviewer credentials.
- Content rating, target audience, ads declaration and production-access status.
- Play App Signing enrollment, upload certificate fingerprints and Firebase/API
  provider registration.
- Pre-launch report, device catalogue exclusions and staged rollout setup.

## Remaining device matrix

Execute every numbered scenario in the feature documents with screenshots and
sanitized logs. Minimum release devices are API 24, API 29, API 33 and API 36,
including one small/low-memory physical device. Repeat the cross-feature smoke
suite for member, church admin and super admin, then verify notification deep
links from foreground, background and terminated states and Church A/B tenant
isolation.
