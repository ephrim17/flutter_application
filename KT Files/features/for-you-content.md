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
- The Daily Verse card is the verse and nothing else, with one bar of
  controls along its bottom edge: the reference pill on the left, then the
  Tamil/English toggle, then the share icon. Its title sits **outside** the
  card as an ordinary `SectionHeader`, the same as every other For You
  section — it used to be drawn inside the card, which left the card
  announcing itself while its neighbours were announced from above. The card
  no longer carries a `forYouPrimaryCardHeight` floor either: that existed to
  keep it from looking stunted while it held the title, and with the title
  gone it only showed as dead space under the bottom bar. `maxLines: 1` on
  `ScriptureReferencePill` keeps a long reference from overflowing the bar.
  Pinned by `test/daily_verse_card_test.dart`.
- Its share icon (and Favorite Verses' share action — see
  [Bible and Favorites](bible-and-favorites.md)) opens a choice sheet:
  **"Create an AI prompt"** or **"Create manually"**. If the verse cannot be
  loaded the card says so instead of crashing or printing a raw error, and
  the whole bottom bar is hidden with it.
  - **Create manually** is the full editor — background color/photo/
    template, layout, style, footer, download. Every manual card shows a
    branding pill (church logo, title, contact number), suppressed for guest
    shares.
  - **Create an AI prompt** opens the **Poster prompt** builder
    (`widgets/modals/verse_prompt_builder_screen.dart`). The app no longer
    generates AI images: the person picks how the poster should look, taps
    **Copy prompt**, and pastes the prompt into ChatGPT or Gemini, so the
    image is made (and paid for) in their own account. The builder mirrors
    the "Daily Bible Verse Poster — Master Prompt Builder"
    (tcsong.com/prompteasy/DBVPoster1.html) and its prompt is word-for-word
    what that page produces for the same choices (pinned by
    `test/verse_poster_prompt_test.dart`). Six sections: top name + style
    and an optional date (4 formats, 5 placements); optional title; verse
    text, reference, font size, position and language/script; verse and
    reference text styles; background scene + colour theme; art style,
    size/platform and mood; and an optional footer (ministry name, contact,
    attached logo, style). The prompt preview updates as you type;
    **Reset** restores the defaults.
    - The reference builder's **"Your own photo (optional)"** section is
      deliberately *not* reproduced (removed 2026-11-10). It asked the
      person to attach a real photo and emitted an "ATTACHED PHOTO —
      STRICT" block telling the model to keep the face 100% original —
      wording no image model actually honours, so it promised something the
      output could not deliver. `versePosterPhotoPlacements` and the
      `usePhoto`/`photoSubject`/`photoPlacement` options went with it, which
      is why the generated prompt no longer matches that page byte-for-byte
      when the photo toggle would have been on.
  - Prefill: verse text and reference come from the verse being shared; the
    language defaults to Tamil when the verse contains Tamil script, else
    English; the top name and footer ministry name are the selected
    church's name and the footer contact its contact number, with the footer
    on whenever the church has either. A guest share prefills no church
    name or contact.
  - The option phrases (styles, themes, placements…) are English prompt
    vocabulary shown and pasted verbatim, so they are code constants in
    `helpers/verse_poster_prompt.dart` rather than localized text; all
    surrounding labels use `ui.verse_prompt.*` keys.
  - **Retired (2026-11-09):** Gemini-rendered verse cards — the For You
    image carousel, Studio's once-a-day "Generate images" button, and the
    on-demand AI generation from the share sheet and the Bible reader. The
    app no longer calls `generateVerseBackgroundImage`; the function
    (`functions/src/verseImage.ts`, `dailyVerseCache.ts`) is still in the
    source and deployed because older installed app versions call it. Its
    former design is in
    [Daily Verse card caching](../architecture/daily-verse-card-caching.md).
- Featured For You is the consolidated featured/plans presentation.
- Articles are admin-authored, record `createdBy`/`updatedBy` footprints and
  show author details like feed cards. Tapping the author opens the common user
  card.
- A newly created article queues a notification to church members; tapping it
  opens the article destination.
- Bible Swipe content is versioned so configured verse changes can refresh
  local data.
- Reading-plan progress is scoped to church and user.

## The Pray for others rail

The rail is a `SnappingCardRail` (`widgets/snapping_card_rail.dart`), not a
`PageView`. It has no fixed height: it takes the height of its **tallest**
card and gives every card that height, so a request with a one-line
description renders at the same size as one with three. Before that, each
card ended wherever its own text stopped, and two cards side by side in the
same rail had different bottom edges — the same content at two different
sizes, next to each other.

`PrayerRequestCard` takes a `fillHeight` flag for this. The rail sets it, so
the rule and the author/expiry line are pinned to the card's own bottom edge
rather than floating wherever the description ended. The Prayer Requests
screen leaves it off, because there a card is only as tall as its content.

Three things say there is more than one card: the next card peeks 30px past
the edge, the rail settles on a card rather than wherever it was released,
and the dots say how many there are. The dots are tappable, which is the way
across without a long swipe.

The settle runs on a 140ms debounce rather than on `ScrollEndNotification`
alone: a wheel or trackpad produces scroll updates without the clean end
notification a finger lift gives, so waiting for that notification left the
rail parked half-way between two cards. It advances on a quarter of a card's
movement rather than the nearest card, because a card is nearly the full
width and "nearest" would mean travelling 600px before anything happened.

`test/snapping_card_rail_test.dart` pins the equal heights, the peek and the
dots; `test/prayer_card_fill_height_test.dart` pins the footer.

## Technical map

- Registry: `screens/for_you/for_you_screen.dart`.
- Equal-height rail: `widgets/snapping_card_rail.dart`.
- Sections: `screens/for_you/sections/`.
- Reading plans: `screens/for_you/reading_plan/`.
- Bible swipe: `screens/for_you/bible_swipe/`.
- Providers: `providers/for_you_sections/`.
- Repositories: `services/for_you_section/` and Studio repository.
- Article data: `churches/{churchId}/articles/{articleId}`.
- Verse sharing: `widgets/modals/verse_share_modal.dart`
  (`showVerseShareChoiceSheet`, `VerseShareModal`); AI prompt builder:
  `widgets/modals/verse_prompt_builder_screen.dart`
  (`showVersePromptBuilder`) over `helpers/verse_poster_prompt.dart`
  (`buildVersePosterPrompt`).

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| FORYOU-01 | Configure enabled/order values | Registry renders only enabled sections in exact order. |
| FORYOU-02 | Missing optional config | Documented default sections still render safely. |
| FORYOU-03 | Daily Verse reference | Correct verse loads; plain card has no gradient/overflow. |
| FORYOU-03c | Look at the Daily Verse card next to the sections below it | "Daily verse" is a heading above the card, aligned with "Pray for others" and "Featured For you"; the card itself has no title. Reference, language toggle and share sit on one line along the card's bottom edge, in that order, with no empty space beneath them. |
| FORYOU-03d | Toggle Daily Verse between Tamil and English | Verse and reference both switch; the bottom bar keeps its order and stays on one line in both languages. |
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
| FORYOU-14 | Tap Daily Verse share icon | Choice sheet opens with "Create an AI prompt" / "Create manually"; each opens the correct screen. No image carousel is shown on the card. |
| FORYOU-15 | Create an AI prompt from the Daily Verse (Tamil toggled) | Poster prompt opens with the Tamil verse and reference prefilled, language "Tamil (தமிழ்)", the church name as the top name and footer ministry, and the church contact in the footer. |
| FORYOU-16 | Change options in each of the 6 sections | The prompt preview at the bottom updates immediately; turning off date/title/footer removes that section from the prompt. |
| FORYOU-16b | Read through the whole prompt builder | There is no "Your own photo (optional)" section, no photo toggle or placement picker, and the copied prompt never contains an "ATTACHED PHOTO — STRICT" block. Sections are numbered 1–6 with no gap. |
| FORYOU-17 | Tap Copy prompt, paste into ChatGPT or Gemini | Snackbar confirms the copy; the pasted text is the full prompt as previewed and produces a poster with the verse text spelled exactly. |
| FORYOU-18 | Create an AI prompt from Favourites with no church (guest shell) | No church name or contact is prefilled anywhere in the prompt. |
| FORYOU-19 | Tap Reset after editing | Every field and dropdown returns to its prefilled default. |
| FORYOU-20 | Admin opens Studio → Daily Verse | English and Tamil text and references are previewed; there is no "Generate images" button. |
| FORYOU-21 | Daily Verse whose text cannot be loaded | The card shows "Today's verse couldn't be loaded" and no share icon; no crash, no raw error text. |
| FORYOU-22 | Pray for others holding two requests of very different lengths | Both cards are the same height and width, with one bottom edge across the rail; each card's author/expiry line sits on its own bottom edge. |
| FORYOU-23 | Scroll the Pray for others rail with a wheel, a trackpad and a drag | It settles on a card every time, never half-way between two; the next card peeks past the right edge beforehand. |
| FORYOU-24 | Tap the second dot under the rail | The rail moves to that card and the dot fills. |
| FORYOU-25 | Open the same request in Prayer Requests and in Pray for others | Padding, type and clamps match; in the list the card is only as tall as its content. |
