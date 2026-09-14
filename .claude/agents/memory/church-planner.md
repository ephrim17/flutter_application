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

## Planning mistakes to avoid repeating

- Wrote `file:line` references from memory; several were wrong and needed a
  correction pass. Verify each one, and cite the symbol name alongside.
- Put `grep -rn "FirebaseFirestore.instance"` in a plan as an acceptance
  criterion — unescaped `.`, and it matches the new correct
  `instanceFor` code as a substring. Run any command before making it a
  gate.
- Left a plan's status header at "no code written yet" after implementation
  shipped. Stale status on a handover doc actively misleads.

## Corrections received from the user

- (none yet)
