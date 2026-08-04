# Testing Strategy and Release Gates

## Test layers

1. **Static checks**: formatting, analyzer, TypeScript lint/build, text policy,
   and clean diffs.
2. **Unit tests**: parsing, business rules, sorting, access calculations and
   repository-independent logic.
3. **Widget tests**: shared components, overflow-prone layouts, navigation
   controls and user interaction.
4. **Firebase integration tests**: Auth, Firestore, Storage, Cloud Functions,
   email and FCM in an isolated test project or emulator environment.
5. **Manual end-to-end tests**: Android, iOS and web flows using realistic
   roles, data and lifecycle transitions.

## Standard QA identities and data

Maintain non-production test identities for:

- signed-out visitor;
- pending member;
- approved member in Church A;
- member belonging to Church A and Church B;
- Church A admin;
- Church B admin;
- enabled super admin;
- disabled/non-super-admin account.

Maintain two churches to detect tenant leakage, at least two families, two
groups, active and expired content, a live/non-live YouTube configuration, and
both published and disabled learning modules. Never execute destructive test
cases against production member data.

## Scenario execution record

For every numbered scenario record:

| Field | Required evidence |
|---|---|
| Build | Version and commit SHA |
| Environment | Emulator/test Firebase project |
| Platform | Android model/API, iOS version, or browser/version |
| Role | Test identity and selected church |
| Result | Pass, fail or blocked |
| Evidence | Screenshot/video plus relevant sanitized logs |
| Defect | Issue link and severity when failed |

## Common checks for every feature

- Happy path completes and persists after relaunch.
- Loading state does not flash stale data from another church.
- Empty state provides the correct next action.
- Network failure is recoverable and does not duplicate writes.
- Double-tap does not create duplicate records or requests.
- Member/admin/super-admin boundaries are enforced.
- Switching churches cannot expose or mutate the previous church's data.
- Long English and translated text do not overflow at large text scale.
- Keyboard, safe areas, small screens and rotation policy are respected.
- Screen readers receive meaningful labels and controls meet tap-target needs.
- Dates use the intended timezone and expired content disappears correctly.
- External launchers ask for confirmation before phone, email or maps.

## Automated release commands

Run from the repository root:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze lib/church_app test
flutter test
npm --prefix functions run lint
npm --prefix functions run build
git diff --check
```

Release candidates additionally require:

```bash
flutter build apk --release
flutter build ios --release --no-codesign
flutter build web --release
```

## Cross-feature smoke suite

1. Fresh install: onboarding, login and church selection.
2. Member: Home, For You, Feed, Go Further and every enabled drawer item.
3. Admin: Dashboard, Studio mutation, member approval, equipment and one
   notification.
4. Super admin: enter super-admin mode, open a church, change/revert one safe
   test setting, and inspect learning results.
5. Create and consume one feed post, prayer request, article, Daily Faith loop,
   Circle response and Bible learning completion.
6. Verify notification deep links from foreground, background and terminated
   app states.
7. Switch between Church A and Church B and repeat a data read/write to prove
   tenant isolation.
8. Run offline/poor-network checks, background/resume, logout/login and app
   relaunch.

## Severity guide

- **Blocker**: crash, authentication bypass, tenant leak, password-reset flaw,
  data loss, or release cannot start.
- **Critical**: primary feature unusable, privileged action exposed, payment or
  notification fan-out to the wrong audience.
- **Major**: important path broken with a workaround, persistent overflow, or
  incorrect business state.
- **Minor**: cosmetic issue, copy defect or low-impact inconsistency.

