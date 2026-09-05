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
| HOME-07 | Notification, birthday and announcement prompts all eligible | Notification appears first; after each dismissal the next eligible alert appears, with each shown at most once per session and one drag handle. |
| HOME-08 | Empty/error/loading data | No crash; stable empty or recoverable state appears. |
| HOME-09 | Welcome/streak around day boundaries | Greeting and streak remain correct for local timezone. |
| HOME-10 | Contact/social action | Confirmation precedes external app and cancellation stays in app. |
