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
    Function) with the verse's own text/reference plus the church's full
    name (not the short Studio "app title" abbreviation — Gemini's banner
    has room the manual editor's on-screen branding pill doesn't), contact
    number and today's date (human-readable, e.g. "12 September 2026").
    Gemini renders a *complete* devotional card itself — a top banner
    reading "Praise the Lord" with the date in the top-right corner, and a
    decorative bottom banner with the church's full name in bold all-caps
    (sized/wrapped to fit rather than truncated) plus a "For prayer" ribbon
    and phone icon + contact number (both shared by every candidate) — not
    just a plain background for the app to composite. The 3 candidates are
    deliberately **not** 3 rolls of the same prompt — one card in each of
    three distinct styles: (1) a flat-design infographic card (verse text
    as the centerpiece, with 2-3 small icon-and-short-label callouts on
    its key theme); (2) a vibrant photographic "WhatsApp-forward"
    devotional poster (a contemporary person against a golden-hour
    outdoor scene with a distant cross-topped hill, the verse broken
    into short phrases stacked as bold colorful icon-labeled banner
    strips, a larger summary-line banner, and the reference in a small
    leaf-flanked pill — modeled on real South-Indian-church shareable
    graphics, not painted ornamental lettering); (3) a mood-background card (a
    photographic/painterly background matching the verse's mood, with
    decorative typography — bold/accent-colored key phrases, underline
    highlights). Shown full-screen and swipeable (with a page-dot
    indicator) so the person can compare all 3 styles side by side;
    downloading saves whichever candidate is currently on screen — no
    editor step, since each candidate is already final.
  - No candidate renders a church **logo**. The model would invent a
    plausible-but-wrong emblem for a real, named ministry, so church
    identity reaches the card only as text through the shared footer
    banner. Compositing the church's real logo onto a finished card is a
    possible follow-up, not something the prompt should ever ask for.
  - AI generation is capped per user per day in production
    (`AI_IMAGE_DAILY_CAP`, strictly 1 "generate" action per day, worth up
    to 3 candidates) and fails gracefully with a friendly message on quota
    or generation errors. One hardcoded email bypasses this cap for
    testing (temporary, see the `unlimitedTestEmail` comment in
  - The 3 candidates generate in parallel and the whole request is bounded
    end to end so the loading dialog can never hang indefinitely: the
    Cloud Function itself has a 180s execution timeout, each individual
    Gemini call inside it is separately aborted at 90s (so one slow
    candidate can't sink the other two), and the client wraps its own call
    with a 130s hard `.timeout()` backstop regardless of what the
    `cloud_functions` plugin's own timeout does. This closes a real bug
    found live: the plugin's 60s default timeout fired a client-side
    socket error around 45-50s in without ever rejecting the awaited
    Dart future, leaving the non-dismissible "Creating your images..."
    dialog stuck for 9+ minutes with no error shown.
    `verseImage.ts`).
  - The verse reference passed to both share paths (and shown on the Daily
    Verse card itself) now follows the Tamil/English toggle correctly —
    previously it stayed in English regardless of the toggle.
  - Spelling-accuracy fix (2026-09): the mixed-script reference garbling
    (e.g. "Psalms 5:3" inside a Tamil-script card) and the infographic
    style's garbled invented icon-label phrases (e.g. "oreak word") were
    both confirmed live and fixed by (1) switching the model from
    `gemini-3.1-flash-image` to the higher-fidelity `gemini-3-pro-image`,
    (2) adding an explicit shared "every letter must be spelled correctly"
    instruction to all 3 style prompts (previously only one of three said
    "correctly spelled"), and (3) requiring the infographic style's icon
    labels to be verbatim words/phrases lifted from the verse text instead
    of model-invented wording. Re-verified live across 6 candidates (a
    Tamil and an English generation, all 3 styles each): zero letter-level
    spelling/garbling in any candidate. `gemini-3-pro-image` generation
    completed within ~60-99s per action, comfortably inside the 180s
    function timeout / 130s client timeout.
  - Known remaining minor issues (not spelling, lower priority): the
    mood-background style has been observed dropping a single word from a
    longer Tamil verse body (a content omission, not a misspelling); the
    devotional-poster style occasionally turns the reference into its own
    phrase strip and repeats the full verse in the "summary" banner instead
    of a short takeaway; a phone icon has been observed rendering as a
    prohibition-sign-like glyph on at least one Tamil candidate. Manual
    creation remains available as a fully reliable alternative regardless.
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
| FORYOU-15 | Generate with AI | Up to 3 complete verse-card candidates (verse text, decorative typography, church banner with name/"For prayer"/contact number/date all baked in) open full-screen and swipeable, with a page-dot indicator; downloading saves whichever candidate is currently visible, no editor step. |
| FORYOU-16 | Exhaust the daily AI quota (1/day in production), then generate again | Friendly "reached today's limit" message appears; no raw error, no partial state. |
| FORYOU-17 | Generate with AI and swipe all 3 candidates | Each candidate is a different style — one infographic, one photographic devotional poster (person + golden-hour scene, colorful icon-labeled phrase banners), one mood background. No two share a style. |
| FORYOU-18 | Generate with AI from a church context, then from Favourites with no church | Neither card shows a church logo or invented emblem; the church-context cards carry the church name in the footer banner only, and the no-church card carries no church branding at all. |
| FORYOU-19 | Create manually, any background | Branding pill (logo, church title, contact number) renders without overflow and survives download/share. |
| FORYOU-20 | Generate with AI when generation is unusually slow (>60s) or a candidate call fails | Loading dialog resolves within ~130s either way — never hangs indefinitely; a slow/failed candidate doesn't block the others, and total failure shows the friendly error, not a stuck spinner. |

