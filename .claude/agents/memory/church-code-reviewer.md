# code-reviewer memory

Durable learnings only — recurring defect patterns actually found in this
repo, false positives to stop flagging, corrections the user gave about
review scope/severity. Not a log of every review. Keep entries terse; prune
anything superseded or turned out wrong.

## Recurring defect patterns actually found here

- Bible-reader highlight-toggle callbacks: `onToggleHighlight`/favorite-icon
  handlers built as `() async { await toggleGlobalHighlight(...); ref
  .invalidate(favoritesProvider); }` with no lifecycle guard between the
  await and the `ref.invalidate` — was present in both
  `lib/church_app/screens/side_drawer/bible_book_screen.dart` (long-press
  highlight menu, a `ConsumerState`) and `lib/church_app/screens/for_you/
  bible_swipe/bible_verse_swipe_screen.dart` (favorite icon, a stateless
  `ConsumerWidget`) — fixed by adding `if (!mounted) return;`/`if (!context
  .mounted) return;` respectively before the `ref.invalidate`. General
  pattern still worth checking: a fire-and-forget `ref.invalidate`/`ref.*`
  call after an `await`, unguarded, in either widget shape.

- **`isGuestShare` threading gaps at every navigation path reaching a
  guest-affecting widget, not just the one being edited.** When adding an
  `isGuestShare`-style flag (suppress church branding/name for guests) to a
  widget reached via multiple navigation chains, check ALL chains, not just
  the one the task description mentions. Real instance: adding "Generate AI
  image" to `VerseScreen`'s long-press menu required `isGuestShare` on
  `VerseScreen`; it was threaded correctly through
  `BibleLibraryScreen`→`BibleBookScreen`/`ChapterScreen` but initially
  missed the *separate* `PlanListScreen`→`PlanDetailsScreen` reading-plan
  path that also constructs a `VerseScreen` and is also opened from
  `GuestSideDrawer`. `grep -rn "VerseScreen(\|<WidgetName>("` for every
  construction site before declaring guest-threading complete, and check
  each site's own reachability from `GuestSideDrawer`.

## False positives — stop flagging these

- **`ref.mounted` does not exist on `WidgetRef` in this repo's pinned
  `riverpod: ^3.1.0`** — `flutter analyze` errors with `undefined_getter`.
  Don't recommend `ref.mounted` as the fix for a post-await `ref.*` call;
  use the *widget's* `mounted` (State/ConsumerState) or `context.mounted`
  (stateless ConsumerWidget/build-context available) instead, and verify
  any suggested API against `flutter analyze` before reporting it as a fix.

## Corrections received from the user

(none yet)
