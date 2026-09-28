# Bible Library and Favorites

## Purpose

Members can choose a Bible version, download/read supported Bible content,
navigate books and chapters, adjust reading presentation and save favorite
verses. Bible reference pickers are reused by Studio, Daily Faith and Learning.

## Behaviour and data

- Bible version catalogue comes from global `bible_versions` configuration and
  bundled/remote catalogue logic.
- Platform-specific filesystem adapters handle downloaded Bible files; web uses
  its supported storage path.
- Reader navigation loads book/chapter content and exposes verse actions.
- Favorites are user scoped and displayed in the drawer with a compact count.
- Favorite Verses' share action opens the same AI-or-manual verse-share
  choice sheet Daily Verse uses — see
  [For You Content](for-you-content.md) for the full behaviour.
- Verse selection components validate book, chapter, starting verse and ending
  verse against available chapter data.
- Reader font-size/preferences persist locally where implemented.
- Chapter reader app bar has an "AI Summary" action that summarizes the whole
  currently-visible chapter. Long-pressing a verse opens a popup with four
  actions — Highlight/Un-highlight (replaces the old plain-tap toggle),
  Summarize with AI (verse-scoped), Generate AI image, and Share as text.
  Both summary paths
  call Gemini through a fixed, tutor-style prompt (never a free-form user
  prompt) and return a short bilingual (Tamil + English) bulleted
  explanation, shown in a bottom sheet.
- Generate AI image reuses the same `generateVerseBackgroundImage` flow and
  3-style swipeable picker described in
  [For You Content](for-you-content.md), skipping the "Generate with AI" vs
  "Create manually" choice sheet (long-pressing a verse is already an
  explicit AI choice) and instead asking **English or Tamil** first, via the
  shared `showVerseLanguageChoiceSheet` in `verse_share_modal.dart` — the
  same two-option sheet Favourites uses. The chosen language decides *both*
  halves of what the card renders: the verse text (`verse['text']['english']`
  vs `['tamil']`) and the reference, built from `book.key` (English name) or
  `book.name` (Tamil name) so a Tamil card reads "ஆதியாகமம் 23:2", not
  "Genesis 23:2". Dismissing the sheet cancels — it never falls back to a
  default script, since a wrong-language card would still spend the user's
  one daily generate. Previously this path hardcoded the Tamil text with the
  English reference, because the reader shows Tamil as its primary line.
  `isGuestShare` is threaded through every path that can reach `VerseScreen`
  — `BibleLibraryScreen` → `BibleBookScreen`/`ChapterScreen`, and separately
  `PlanListScreen` → `PlanDetailsScreen` (reading plans) — from each drawer's
  own entry point (`true` from the guest shell, `false` from the member
  drawer/For You tab), matching how `FavoritesScreen` already does it, so a
  guest's card never carries an invented church name regardless of stale
  `selectedChurchProvider` state.
- Chapter paging is resolved by `helpers/chapter_paging_window.dart`
  (`resolveChapterPagingWindow`), which distinguishes the reader's two entry
  intents. Opening a chapter from the Bible reader has **no end bound**, so
  the `PageView` spans the *whole book* and the entry chapter is merely its
  initial page — the reader can swipe back past it. A reading plan opens a
  chapter *range* (`PlanDetailsScreen` passes both bounds), so the window
  stays clamped to that range and opens at its first chapter. Fixes a bug
  where the window always started at the entry chapter: opening Exodus 8,
  swiping forward twice to Exodus 10, then back three times stopped dead at
  Exodus 8 instead of reaching Exodus 7, for every book. Out-of-range input
  is clamped rather than thrown (chapter counts differ between versions and a
  stored plan range can outlive a version switch).
- Share as text shares the single long-pressed verse as plain text in both
  scripts, each under its own language's reference (English block first, then
  Tamil), built by the top-level `buildVerseShareText` in
  `bible_book_screen.dart`. An empty script is dropped rather than shared as
  a bare reference, and a verse with neither script opens no share sheet at
  all. This replaced the reader app bar's share icon, which shared the
  chapter's *highlighted* verses only and silently did nothing when none were
  highlighted — sharing is per-verse from the long-press menu now, next to
  the other verse actions. The app bar keeps only the font-size control and
  the chapter AI-summary icon.
- AI summaries are rate-limited server-side, checked before calling Gemini:
  1 chapter summary and 5 verse summaries per user per UTC day. A hitting the
  cap shows a friendly "come back tomorrow" message instead of a raw error.
  One hardcoded email bypasses both caps for testing (temporary, see the
  `unlimitedTestEmail` comment in `bibleSummary.ts`).

## Technical map

- UI: `bible_library_screen.dart`, `bible_book_screen.dart`,
  `favorite_verses_screen.dart`, Bible reader widgets.
- Repositories: `bible_versions_repository.dart`,
  `bible_download_repository.dart`, `bible_book_repository.dart` and filesystem
  adapters.
- Providers: `bible_versions_provider.dart`, `favorites_provider.dart`.
- Shared picker: `widgets/bible_verse_picker_sheet.dart`.
- AI summary: `functions/src/bibleSummary.ts` (callable
  `summarizeBibleContent`, region `us-central1`), called from
  `bible_book_screen.dart`. Quota state lives in
  `users/{uid}/bibleSummaryUsage/{yyyy-mm-dd}` (`chapterCount`/`verseCount`
  fields, each against its own cap), read-only for the owner client-side —
  only the callable's Admin SDK writes it.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| BIBLE-01 | Load catalogue | Supported versions appear; loading/error can retry. |
| BIBLE-02 | Download/cancel/retry version | Progress is accurate, partial failure recovers and file validates. |
| BIBLE-03 | Open book/chapter and navigate | Correct verses load with no stale previous chapter. |
| BIBLE-04 | Offline after successful download | Downloaded content remains readable. |
| BIBLE-05 | Pick verse/range | End stays within chapter and never precedes start. |
| BIBLE-06 | Add/remove favorite | Favorite list and drawer count update immediately and persist. |
| BIBLE-07 | Duplicate favorite | One logical saved verse remains. |
| BIBLE-08 | Change font size/theme | Reader remains legible and preference persists. |
| BIBLE-09 | Web vs mobile storage | Each platform uses supported adapter without filesystem crash. |
| BIBLE-10 | Corrupt/missing local file | Actionable retry/redownload state appears. |
| BIBLE-11 | Tap chapter AI-summary icon | Loading dialog then a bulleted Tamil+English summary sheet, no overflow. |
| BIBLE-12 | Long-press a verse, tap Summarize with AI | Same bilingual bulleted summary, scoped to that one verse. |
| BIBLE-13 | Long-press a verse, tap Highlight/Un-highlight | Highlight toggles and the popup label/icon flips accordingly. |
| BIBLE-14 | Exceed the daily chapter or verse summary cap | Friendly limit-reached message; no Gemini call is made. |
| BIBLE-15 | Long-press a verse, tap Generate AI image | An English/Tamil sheet appears first (no "Generate with AI vs Create manually" choice sheet), then the same 3-style swipeable AI card picker as Daily Verse/Favourites, scoped to that one verse; downloading works with no editor step. |
| BIBLE-15b | Long-press a verse, tap Generate AI image, choose Tamil | Cards render the Tamil verse text under the Tamil reference (e.g. "ஆதியாகமம் 23:2"), not the English book name. Choosing English gives English text with the English reference. |
| BIBLE-15c | Long-press a verse, tap Generate AI image, dismiss the language sheet (back/swipe down) | Nothing generates, no loading dialog appears, and the daily AI quota is not spent. |
| BIBLE-16 | Generate AI image from the guest shell's Bible reader | Card carries no church name/logo/contact — same no-branding guarantee as guest Favourites sharing. |
| BIBLE-17 | Long-press a verse, tap Share as text | The OS share sheet opens with that one verse in both scripts, English text under its English reference and Tamil text under its Tamil reference. |
| BIBLE-18 | Open the Bible reader app bar | Only the font-size control and the chapter AI-summary icon remain; the old share icon is gone and no action is orphaned by its removal. |
| BIBLE-19 | Open Exodus 8, swipe forward twice, then back three times | Chapters track 8 → 9 → 10 → 9 → 8 → **7**; swiping back past the chapter you opened on works, and the app bar's chapter number follows every swipe. |
| BIBLE-20 | Open chapter 1 of any book and swipe back; open the last chapter and swipe forward | Neither swipe leaves the book or shows a blank page. |
| BIBLE-21 | Open a reading plan day covering a chapter range (e.g. Exodus 8-10) | Paging stays inside the assigned range — it opens on the range's first chapter and cannot swipe to the chapter before or after it. |
| BIBLE-22 | Tap the chapter AI-summary icon right after opening a chapter, before swiping | The summary is for the chapter on screen, not chapter 1. |

