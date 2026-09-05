---
name: release-check
description: Runs this repo's automated release gate (dart format check, flutter analyze, flutter test, Cloud Functions lint/build, git diff --check) and reports current release-readiness status against the known blockers tracked in the testing docs. Use before merging release-relevant work or when asked "are we ready to release" / "run release check".
---

Run the automated release gate for this Flutter/Firebase app and report a clear pass/fail summary.

## Steps

1. Run these commands from the repo root, in order, capturing output for each:
   ```
   dart format --output=none --set-exit-if-changed lib test
   flutter analyze lib/church_app test
   flutter test
   npm --prefix functions run lint
   npm --prefix functions run build
   git diff --check
   ```
2. Report each command's pass/fail status. On a failing step, show the relevant error output and stop there — do not silently continue past a failing step, and do not attempt fixes unless asked.
3. Only if `$ARGUMENTS` includes `--full`, additionally run the slower release-candidate platform builds:
   ```
   flutter build apk --release
   flutter build ios --release --no-codesign
   flutter build web --release
   ```
   Skip these by default.
4. Find the most recent release-readiness doc — look for `KT Files/testing/android-release-readiness-*.md`, falling back to `docs/testing/android-release-readiness-*.md` if the KT Files reorg hasn't merged into this branch yet — sorted by the date in the filename. Read it and summarize its "Release blockers" table alongside the fresh gate results. Note that this list may be stale: flag if code you can see suggests a listed blocker has since been closed (e.g., a `firestore.rules` file now exists where the doc said none did), but don't assume a blocker is closed without checking the current repo state.
5. End with one clear verdict line: what currently blocks a release (automated gate failures plus open known blockers) and what's clean.

## Notes

- This mirrors the "Automated release commands" section in the testing handbook (`KT Files/testing/README.md` or `docs/testing/README.md`) — keep this skill's command list in sync if that doc changes.
- Do not use `--no-verify` or skip a step to force a pass.
