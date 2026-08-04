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

## Technical map

- Screen/registry: `screens/home/home_screen.dart`.
- Sections: `screens/home/sections/`.
- Providers: `providers/home_sections/`.
- Services: `services/home_section/` and Studio repository.
- Backend recurrence: `advanceRecurringEventOnWrite`,
  `advanceRecurringEventsHourly`.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| HOME-01 | Load configured sections | Only enabled sections appear in configured order. |
| HOME-02 | Disable/reorder from Studio | Home updates from stream without relaunch. |
| HOME-03 | Active/expired announcement | Active item displays; expired item is absent. |
| HOME-04 | Announcement with/without image | Both layouts render cleanly on smallest supported screen. |
| HOME-05 | Current/upcoming/recurring event | Correct date/type/contact/location display; recurrence advances once. |
| HOME-06 | Promise reference | Correct book/chapter/verse content opens. |
| HOME-07 | Birthday and announcement prompts both eligible | Each appears at most once per session with one drag handle. |
| HOME-08 | Empty/error/loading data | No crash; stable empty or recoverable state appears. |
| HOME-09 | Welcome/streak around day boundaries | Greeting and streak remain correct for local timezone. |
| HOME-10 | Contact/social action | Confirmation precedes external app and cancellation stays in app. |

