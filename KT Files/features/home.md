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

## Wide windows and one left edge

Past `_homeWideBreakpoint` (700) the page stops stretching: its content is
capped at `_homeMaxContentWidth` and centred, because a full-bleed card in a
desktop window reads as a banner rather than a card.

Everything on the page then shares one left edge, and that edge is the
card's, not the column's. A carousel card does not sit flush with its
carousel — a `PageView` below a viewport fraction of 1 insets the page, and
the page is padded by half the carousel spacing — so `homeCarouselCardInset`
is the one place that arithmetic lives and every other surface defers to it:

- Events and Announcements put their heading **inside** the centred column,
  padded by that inset. Previously the heading sat outside the column, so on
  a desktop window it stayed pinned 16px from the window edge while its cards
  centred themselves — 315px adrift at 1280, and more on a wider monitor.
- Promise Word pads its heading by the same inset as its own card. It used to
  pad by 0, putting it on the column edge, 41px left of the card beneath it.
- The welcome card and the footer go through `HomeCardAlign`, which applies
  the cap and the inset together. Neither had any cap before, so both
  stretched to the full window while the carousels did not.
- For You caps itself at `homeCardWidth` plus its own gutter
  (`ForYouContentWidth`), so cards on the two tabs land on the same edges
  instead of For You filling the whole window.

Below the breakpoint none of this changes the width, only the inset: headings
move from 16 to the card edge (26.55 at 411dp), which is what they should
always have lined up with.

`test/home_card_alignment_test.dart` and `test/for_you_content_width_test.dart`
pin these edges at a phone and a desktop width.

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
| HOME-12 | Open Home in a desktop browser window (1280 or wider) | Welcome card, Events, Promise Word, Announcements and footer all share one left and right edge; nothing stretches to the window. |
| HOME-13 | Read each section heading against the card below it in a wide window | Every heading starts exactly where its own card starts — no heading stranded near the window edge. |
| HOME-14 | Switch Home → For You in a wide window | Cards on both tabs sit on the same edges; the page does not change width between tabs. |
| HOME-15 | Narrow the browser back below 700 | Content returns to full width with no horizontal scroll; headings stay on their cards' edge. |
