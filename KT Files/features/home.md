# Home

## Purpose

Home is the church-configured landing page. It combines a personal welcome and
streak card with ordered church sections: announcements, events, promise and
footer content. Birthday and configured announcement prompts can open once per
session.

## Content and control

- Section definitions live under `churches/{churchId}/home_sections`.
- Studio controls section enabled state and order.
- Announcements support title/body, optional image, priority, active state and
  expiry.
- Events support church event details and recurring weekly advancement.
- Promise points to a configured Bible reference.
- Footer renders configured contacts and social links.
- Prompt sheets are session-deduplicated so competing birthday/announcement
  conditions do not display duplicate modal handles.
- Notification enablement is always resolved first. After that sheet is
  dismissed or completed, Home re-checks eligible alerts and presents the
  announcement prompt followed by any remaining alert, one at a time.
- The welcome/streak card shows a "Setup Profile" pill when the signed-in
  user's global `profileComplete` flag is `false`. Tapping it opens the same
  Edit Profile sheet as Settings → Profile → Edit Profile (see
  [Navigation, Profile and Settings](navigation-profile-settings.md)).

## Technical map

- Screen/registry: `screens/home/home_screen.dart`.
- Sections: `screens/home/sections/`.
- Providers: `providers/home_sections/`.
- Services: `services/home_section/` and Studio repository.
- Backend recurrence: `advanceRecurringEventOnWrite`,
  `advanceRecurringEventsHourly`.

## Small screens

The greeting card's streak pill holds its text in a `Flexible`, so it wraps
rather than overflowing. Without it the row overflowed its card by 61px at
320dp — Flutter paints that as a striped banner in debug and silently clips
it in release. Wrapping keeps every word, which an ellipsis would not.

## Page width and one left edge

**Home has no maximum width.** Every section is laid out against the screen
it is on — phone, simulator or a browser window of any size — and the cards
grow and shrink with it, the way For You's always have. There is no
breakpoint, no content column and no centring.

Every section leaves the same gutter at both edges: `homeSidePadding`, a flat
**16**, which is the same value For You uses (`forYouSidePadding`). Headings,
carousel cards, the Promise Word card, the welcome card and the footer all
land on it, so the two tabs read as one page instead of changing shape when
you switch between them.

The gutter is a constant, not a share of the screen. It was briefly a
fraction (`viewportFraction: 0.9`, giving `screenWidth * 0.05 + 6`), which
looks right on a phone and becomes a wide empty margin on a desktop window —
76 at 1400 against For You's 16.

That means **one card fills the carousel** (`viewportFraction: 1.0`). A peek
and a constant gutter cannot both hold: the peek is what pushed the card
inwards by a share of the screen. The dots under a multi-card carousel carry
the "there is more" affordance instead.

A carousel page pads its own card by half the carousel spacing (6), so the
carousel is wrapped in `homeCarouselOuterPadding` — the remaining 10 — to
land the card on 16 rather than on 6. The welcome card and the footer go
through `HomeCardAlign`, which is just that 16.

`DecoratedScriptureCard` sets `width: double.infinity` on its inner
container: it is a non-positioned child of a `Stack`, so it is given loose
constraints and would otherwise shrink-wrap its text and end short of the
card it is supposed to fill.

`test/home_card_alignment_test.dart` pins every heading to its own card, pins
Promise Word to the Events card, asserts the gutter equals `forYouSidePadding`
at 320/411/768/1280/1920 — so the two tabs fail loudly rather than drifting
apart — and checks that nothing overflows at those widths.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| HOME-01 | Load configured sections | Only enabled sections appear in configured order. |
| HOME-02 | Disable/reorder from Studio | Home updates from stream without relaunch. |
| HOME-03 | Active/expired announcement | Active item displays; expired item is absent. |
| HOME-04 | Announcement with/without image | Both layouts render cleanly on smallest supported screen. |
| HOME-05 | Current/upcoming/recurring event | Correct date/type/contact/location display; recurrence advances once. |
| HOME-06 | Promise reference | Correct book/chapter/verse content opens. |
| HOME-07 | Notification, birthday and announcement prompts all eligible | Notification appears first; after each dismissal the next eligible alert appears, with each shown at most once per session and one drag handle. |
| HOME-08 | Empty/error/loading data | No crash; stable empty or recoverable state appears. |
| HOME-09 | Welcome/streak around day boundaries | Greeting and streak remain correct for local timezone. |
| HOME-11 | Sign in with `profileComplete: false` / `true` | Welcome card shows/hides the Setup Profile pill to match; tapping it opens Edit Profile. |
| HOME-10 | Contact/social action | Confirmation precedes external app and cancellation stays in app. |
| HOME-12 | Open Home in a desktop browser window (1280 or wider) | Welcome card, Events, Promise Word, Announcements and footer all grow with the window, leaving the same 16 gutter at both edges; no centred column, no fixed-width card. |
| HOME-16 | Switch Home → For You in the same window | The gutter does not change between the two tabs; cards start and end on the same pixels. |
| HOME-17 | Open a carousel section holding more than one card | Dots appear under the carousel and swiping moves one full-width card at a time. |
| HOME-13 | Read each section heading against the card below it | Every heading starts exactly where its own card starts, at any width. |
| HOME-14 | Drag the browser window from wide to phone width and back | Cards resize smoothly throughout; no overflow stripe and no horizontal scroll at any point. |
| HOME-15 | Open Home on a wide window with a short Promise Word verse | The verse card still spans the full card width rather than shrinking to fit its text. |
