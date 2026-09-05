# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Start with AGENTS.md

`AGENTS.md` at the repo root is the primary rules file and covers: the
user-visible-text localization rule (never raw strings, use
`context.t()`/`ref.t()` + `defaultChurchTextContents`), the architecture map,
church-scoping invariants, and the `mounted`/`ref`-after-dispose rules. Read
it before making changes — this file only adds what it doesn't cover.

## Release verification

Before declaring release-relevant work complete, run:

```
flutter analyze lib/church_app test
flutter test
npm --prefix functions run lint && npm --prefix functions run build
```

(`flutter build apk/ios/web --release` are part of full release verification
but not needed for routine changes — see README.md.)

## Testing

- No mocking library (mockito/mocktail) is in use — tests use real objects
  and fakes, not mocks. Follow that pattern rather than adding a mocking dep.
- Tests accompany reusable UI and behavior changes and live in `test/`.

## Documentation policy

- The product/engineering handbook lives in `KT Files/` (index:
  `KT Files/README.md`), covering system architecture, all 18 feature areas,
  and testing/release status.
- Every user-facing behavior change must update the matching file under
  `KT Files/features/` and its numbered test flows, in the same change.
- Cross-feature test policy and release gates live in
  `KT Files/testing/README.md`.

## Cloud Functions

- Source lives in `functions/` (TypeScript, its own lint/build/deploy
  scripts) — separate from the Flutter app's lint/format/test commands.

## Git workflow

- Solo repo, single `main` branch — commit directly to `main`, no PR/branch
  convention in use.
