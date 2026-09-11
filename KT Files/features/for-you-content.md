# For You Content

## Purpose

For You assembles ordered, church-configurable spiritual content in one scroll,
and hosts the church/global social feed alongside it.

The For You tab is split into two segments at the top:
- **Highlights** — the registry described below (Live Church, Daily Verse,
  Faith Engagement, Bible Learning, Pray for Others, Featured For You, footer
  and Articles).
- **Community** — the church/global feed (see [Feeds](feeds.md)), embedded
  as-is; it is no longer a separate bottom tab.

Switching segments preserves each side's scroll position and (for Community)
feed pagination state, since both are kept alive in an `IndexedStack` rather
than rebuilt on toggle.

This document covers Daily Verse, Featured For You, Articles, Bible Swipe and
Reading Plans. Faith Engagement, Learning, Live Church and Prayer have separate
documents.

## Behaviour

- `churches/{churchId}/for_you_section/{sectionId}` controls enabled state and
  order. Studio controls Faith Engagement sub-items independently.
- Daily Verse uses a church-configured Bible book/chapter/verse reference and a
  plain card presentation. The card grows to fit the verse text (min-height
  only) instead of clipping it, so larger system text sizes remain fully
  readable.
- Tapping the Daily Verse share icon (and Favorite Verses' share action —
  see [Bible and Favorites](bible-and-favorites.md)) opens a choice sheet:
  "Generate with AI" or "Create manually".
  - **Create manually** is the pre-existing full editor, unchanged —
    background color/photo/template, layout, style, footer, download.
    Every manual card always shows a branding pill (church logo, title,
    contact number) so a downloaded/shared image is self-identifying.
  - **Generate with AI** calls `generateVerseBackgroundImage` (Cloud
    Function) with the verse's own text/reference plus the church name and
    today's date. Gemini renders a *complete* devotional card itself —
    background, the verse text (in its original script), and a church
    name/date caption at the bottom — not just a background for the app to
    composite. The callable returns up to 3 candidates; picking one opens
    a simple full-screen preview with a Download button directly (no
    editor step, since the image is already final).
  - AI generation is capped per user per day (`AI_IMAGE_DAILY_CAP`,
    default 5 "generate" actions, each worth up to 3 images) and fails
    gracefully with a friendly message on quota or generation errors.
  - Known quality tradeoff (accepted product decision): letting Gemini
    render the verse text itself is unreliable for non-Latin scripts —
    confirmed live with Tamil content, where the verse body rendered
    correctly but a mixed-script reference (e.g. "Psalms 5:3" inside a
    Tamil-script card) came out garbled. No app-side fallback exists for
    this; manual creation remains available as the reliable alternative.
- Featured For You is the consolidated featured/plans presentation.
- Articles are admin-authored, record `createdBy`/`updatedBy` footprints and
  show author details like feed cards. Tapping the author opens the common user
  card.
- A newly created article queues a notification to church members; tapping it
  opens the article destination.
- Bible Swipe content is versioned so configured verse changes can refresh
  local data.
- Reading-plan progress is scoped to church and user.

## Technical map

- Registry: `screens/for_you/for_you_screen.dart`.
- Sections: `screens/for_you/sections/`.
- Reading plans: `screens/for_you/reading_plan/`.
- Bible swipe: `screens/for_you/bible_swipe/`.
- Providers: `providers/for_you_sections/`.
- Repositories: `services/for_you_section/` and Studio repository.
- Article data: `churches/{churchId}/articles/{articleId}`.
- Verse sharing: `widgets/modals/verse_share_modal.dart`
  (`showVerseShareChoiceSheet`, `VerseShareModal`); backend:
  `functions/src/verseImage.ts` (`generateVerseBackgroundImage`); usage
  cap: `users/{uid}/aiUsage/{yyyy-mm-dd}` (Admin-SDK-write-only, read-only
  for the owner).

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| FORYOU-01 | Configure enabled/order values | Registry renders only enabled sections in exact order. |
| FORYOU-02 | Missing optional config | Documented default sections still render safely. |
| FORYOU-03 | Daily Verse reference | Correct verse loads; plain card has no gradient/overflow. |
| FORYOU-03b | Daily Verse at large system text size | Full verse text is readable; card grows instead of clipping mid-line. |
| FORYOU-13 | Toggle Highlights/Community segment | Correct content shows; Community renders the same feed content/FAB as before the move. |
| FORYOU-04 | Featured content empty/populated | Clean empty behaviour or equal-height content cards. |
| FORYOU-05 | Create article as admin | Article persists with creator footprint and member notification is queued. |
| FORYOU-06 | Article card/list/detail | Author avatar/details render; tapping opens common user card. |
| FORYOU-07 | Long article form/content | Text fields and reading view scroll above keyboard without overlap. |
| FORYOU-08 | Delete/update article | Stream updates once and notification is not duplicated on edit. |
| FORYOU-09 | Bible Swipe config version changes | Client refreshes configured verses and preserves stable navigation. |
| FORYOU-10 | Reading plan progress | Completed days persist for the same church/user and do not leak. |
| FORYOU-11 | Notification opens article | App lands on For You/article list from all lifecycle states. |
| FORYOU-12 | Section error | Other sections remain usable when one provider fails. |
| FORYOU-14 | Tap Daily Verse share icon | Choice sheet opens with "Generate with AI" / "Create manually"; each opens the correct flow. |
| FORYOU-15 | Generate with AI, pick a candidate | Up to 3 complete verse-card candidates appear (verse text, church name, date baked in); picking one opens a full-screen preview with Download, no editor step. |
| FORYOU-16 | Exhaust the daily AI quota, then generate again | Friendly "reached today's limit" message appears; no raw error, no partial state. |
| FORYOU-17 | Create manually, any background | Branding pill (logo, church title, contact number) renders without overflow and survives download/share. |

