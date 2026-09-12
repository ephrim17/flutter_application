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
  currently-visible chapter. Long-pressing a verse opens a popup with two
  actions — Highlight/Un-highlight (replaces the old plain-tap toggle) and
  Summarize with AI (verse-scoped). Both summary paths call Gemini through a
  fixed, tutor-style prompt (never a free-form user prompt) and return a
  short bilingual (Tamil + English) bulleted explanation, shown in a bottom
  sheet.
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

