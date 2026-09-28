# church-planner memory

Durable learnings only — repo constraints discovered while planning,
planning mistakes and their fixes, corrections the user gave. Not a log of
every plan. Keep entries terse; prune anything superseded or wrong.

## Repo constraints discovered while planning

- Firestore rules can't query — `isApprovedMember()` builds the path from
  `request.auth.uid`, so a membership doc must be *keyed* by uid. A
  `linkedUid` pointer field is unimplementable in rules.
- Member search (`members_repository.dart`, `_searchFieldForQuery`) uses
  server-side `orderBy` + prefix range + cursor pagination on the member
  collection. Fields it sorts on cannot live in another document.
- `firestoreProvider` was declared in three files with eight direct
  `FirebaseFirestore.instance` callers — check for duplicate provider
  declarations before any plan that swaps the Firestore instance.
- Church-scoped section config providers return `Stream.empty()` when
  `churchId == null`, which leaves `.when(loading:)` spinning forever
  rather than showing an empty state.
- No Bible text ships as a Flutter asset. `pubspec.yaml` has no
  `assets/bible/`; the only version is `fallbackBibleVersions`
  (`bible_catalog.dart`) with `storagePath: 'bible/english_tamil'`, read from
  Storage (`storage.rules` gives `/bible/**` public read). So Cloud Functions
  *can* resolve verse text server-side with the Admin SDK — useful whenever a
  plan needs to stop trusting client-supplied verse text.
- `storage.rules` has `isChurchAdmin`/`isChurchStaff`/`isSuperAdmin` but **no**
  `isApprovedMember` — any member-scoped Storage path needs that helper added,
  mirroring `firestore.rules`. Use `isChurchAdmin`, not `isChurchStaff`
  (the latter folds in super admin).
- GCS lifecycle rules match a literal object-name prefix — they cannot express
  `churches/*/<thing>/`. Anything that wants free retention must be rooted at a
  bucket-level prefix (`<thing>/{churchId}/...`), not nested under `churches/`.
  Also: `gcloud storage buckets update --lifecycle-file` *replaces* the whole
  lifecycle config; plans must say "merge, don't replace".
- Existing timezone precedent for a church-local day boundary:
  `recurringEventTimeZone = "Asia/Kolkata"` (`functions/src/index.ts`). The AI
  quota helpers use UTC `todayKey()` instead — the two disagree, which matters
  for anything keyed by "today" in India (UTC day flips at 05:30 IST).
- `functions/` has no test runner (`package.json` scripts are lint/build only,
  `firebase-functions-test` is an unused devDependency). Don't write a phase
  exit criterion that assumes `npm test` in functions.

## Planning mistakes to avoid repeating

- Wrote `file:line` references from memory; several were wrong and needed a
  correction pass. Verify each one, and cite the symbol name alongside.
- Put `grep -rn "FirebaseFirestore.instance"` in a plan as an acceptance
  criterion — unescaped `.`, and it matches the new correct
  `instanceFor` code as a substring. Run any command before making it a
  gate.
- Left a plan's status header at "no code written yet" after implementation
  shipped. Stale status on a handover doc actively misleads.
- When a plan turns a per-user action into shared/cached content, re-audit
  every client-supplied input: inputs that were harmless when they only
  affected the caller's own output become a content-poisoning vector once one
  user's request produces the artefact the whole church sees. Resolve them
  server-side and say so in "critical correctness notes".
- `KT Files/features/for-you-content.md` has duplicate test-flow IDs
  (FORYOU-19 and FORYOU-20 each used twice, as of 2026-09-18). Check for
  duplicates with `grep -n "FORYOU-" <file> | awk -F'|' '{print $2}' | sort |
  uniq -d` before assigning new IDs in any feature doc.

## Corrections received from the user

- (none yet)
