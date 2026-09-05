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
- Verse selection components validate book, chapter, starting verse and ending
  verse against available chapter data.
- Reader font-size/preferences persist locally where implemented.

## Technical map

- UI: `bible_library_screen.dart`, `bible_book_screen.dart`,
  `favorite_verses_screen.dart`, Bible reader widgets.
- Repositories: `bible_versions_repository.dart`,
  `bible_download_repository.dart`, `bible_book_repository.dart` and filesystem
  adapters.
- Providers: `bible_versions_provider.dart`, `favorites_provider.dart`.
- Shared picker: `widgets/bible_verse_picker_sheet.dart`.

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

