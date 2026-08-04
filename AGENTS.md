# Church Tree Repository Rules

These instructions apply to the whole repository and must be reviewed before
changing the app.

## User-visible text

- Never add user-visible church-app text as a raw Dart string.
- Add the English default to
  `lib/church_app/models/text_content_defaults.dart` under
  `defaultChurchTextContents`.
- Render it with `context.t('feature.key')` or `ref.t('feature.key')`.
- Use the `parameters` argument for dynamic values, with `{name}` placeholders
  in the default text. Do not build translated sentences with interpolation.
- `preAuthDefaultTextContents` is only for text required before church config is
  available. Church-scoped and shared post-login text belongs in
  `defaultChurchTextContents`.
- Technical constants are not UI text: Firestore field names, collection paths,
  analytics event names, route identifiers, URLs, and enum/storage values stay
  as code constants.
- User-generated content and backend data must remain data and must not be added
  to the defaults map.

## Architecture

- App entry and auth flow: `lib/church_app/screens/entry/`.
- Main shell and tabs: `lib/church_app/screens/church_tab_screen.dart`.
- Feature screens: `lib/church_app/screens/`; reusable UI:
  `lib/church_app/widgets/`.
- Riverpod state and dependency wiring: `lib/church_app/providers/`.
- Firebase and domain operations: `lib/church_app/services/`.
- Firestore path construction must go through
  `lib/church_app/services/firestore/firestore_paths.dart` when available.
- Serializable/domain types: `lib/church_app/models/`.
- Shared validation, formatting, launchers, and localization extensions:
  `lib/church_app/helpers/`.
- Cloud Functions source: `functions/src/`; Firestore indexes:
  `firestore.indexes.json`.
- Tests belong in `test/` and should accompany reusable UI and behavior changes.

## Feature documentation

- Product and engineering documentation lives in `docs/` and is indexed by
  `docs/README.md`.
- Every user-facing behaviour change must update the matching file under
  `docs/features/` and its numbered test flows.
- Cross-feature test policy and release gates live in `docs/testing/README.md`.
- Keep documentation aligned with actual role checks, feature flags, Firestore
  paths, Cloud Functions and dormant-feature status.

## Implementation invariants

- Preserve church scoping on all reads and writes.
- Church admin access is derived from the current church config; super admin is
  global and separate.
- Prefer shared components such as `AppTextField`, `AppDropdownField`,
  `AppBottomTabBar`, `AppPopupMenu`, and `showAppModalBottomSheet`.
- Check `mounted` after awaits before using `BuildContext` or a Riverpod `ref`.
- Do not read `ref` after a `ConsumerState` has been deactivated or disposed.
- Run formatting, focused analysis, the full Flutter test suite, and
  `git diff --check` before declaring work complete.
