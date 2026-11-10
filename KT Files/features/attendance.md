# Attendance

## Purpose

Record a gathering and who was at it, so a church can see whether the people
it is responsible for are still turning up. The headline number is not the
head count — it is **"not seen for 3 services"**, the list of active members
worth a phone call.

Modelled on [ShepherdDesk](https://tcsong.com/shepherddesk/#attendance),
which the owner pointed at as the reference. What was taken from it and what
was deliberately left out is in [Scope](#scope-v1) below.

## Views and rules

- **The service is the record, not the person.** A service carries a date, a
  service type, an optional free-text subheader, a visitor headcount, a
  children headcount, free-text notes (preacher, theme) and `present`, a
  plain array of member document ids.
  Attendance is not a row per person per service: a church marks a whole
  congregation in one sitting, so one document written once is cheaper and
  far easier to correct than N writes that can half-succeed.
- **The subheader is the church's own name for one gathering** — "2nd
  service", "Tamil service", "Youth-led" — and it is what tells two services
  of the same type on the same date apart. Three Sunday worships in a day is
  the ordinary case, not the edge case, and without it the card, and the
  heading of the marking sheet, name all three identically. Free text, not
  another key list: only the church knows what it calls its own services, and
  a fixed list would be wrong everywhere. Capped at 60 characters because it
  is a card line, not a paragraph — `notes` is the field for prose. Empty is
  normal and renders nothing, which is also what every service recorded
  before the field existed reads as.
- **Recording and marking are one task.** Saving a new service goes straight
  into the marking sheet, because a register is taken with people still in
  the room.
- **Marking is local until Save.** Taps mutate an in-memory set; one write
  lands on Save. A write per tap would be a hundred writes and a hundred
  chances for a flaky connection to leave the register half-recorded.
- **Household check-in** (on by default) marks everyone sharing a
  `familyId` when you tap one of them, and each row offers an explicit
  `+N family` button. **Un-marking is always just the one person** — tapping
  someone off should never silently remove their family, because the usual
  reason is a mis-tap on one name.
- A blank `familyId` is "not in a family", never a family. Treating blank as
  a shared key would make one tap mark every unlinked member in the church.
- The roster is **approved members only**, sorted by name. The percentage and
  the absence streak are measured against that roster, never against everyone
  ever marked present — so a non-roster id raises the head count but can
  never push "of active members" past 100%, and is never chased for absence.
- **Staff only, read as well as write.** A register of who was in the
  building is not something the congregation browses, and unlike the member
  directory there is no reduced mirror to offer them instead. The drawer
  entry is `adminOnly` and appears only where Members is enabled, since
  attendance is marked against the member roster.

## Statistics

| Number | Definition |
|---|---|
| Present at last service | `present.length` of the most recent service by date |
| Average, last 8 services | Mean `present.length` over `attendanceAverageWindow`, rounded |
| Of active members, last service | Roster members present at the last service ÷ roster size |
| Not seen for 3 services | Roster members absent from **every** one of the last `attendanceAbsenceStreak` services |

The absence streak is empty until that many services exist — you cannot miss
three services that never happened — and its ids are sorted, so the count
cannot shuffle between rebuilds. Three is deliberately not one: a single
absence is a Sunday away, three in a row is a pattern.

The trend chart reads **oldest to newest, left to right** (the reading order
of a timeline) which is the opposite of the service list below it, newest
first. It is hand-drawn `Container` bars; twelve bars and a date label do not
justify a charting dependency.

## Scope (v1)

Taken from ShepherdDesk: service types, the visitor/children headcounts, the
tap-down-the-roster sheet with search and a running tally, household
check-in, the four statistics and the trend chart.

Deliberately **not** built, per the owner's decision:

- **QR check-in and printed member cards.** The reference scans a code on a
  card to mark someone. The app has no cards, no code format and no scanner;
  that is a feature of its own, not a detail of this one.
- **Group leaders marking their own group.** Marking is church-admin only,
  which is the app's existing authority (`config/app.admins`) with no new
  role and no new rules helper. A leader concept on `churches/{id}/groups`
  would be needed first.
- **Member self check-in.** A different model entirely: per-member writes, an
  open/closed window per service, and spoofing becomes a real concern.
- **"+ New visitor" from the marking sheet.** In the reference this writes a
  real member record with status `Visitor`. The app has no visitor status, so
  visitors are the headcount field only.
- **Branches.** The reference is multi-branch; this app is one church per
  selected `churchId`.

## Technical map

- Screens: `screens/side_drawer/attendance_screen.dart` (stats, trend,
  type filter, service list) and `attendance_mark_screen.dart` (the roster
  sheet). Form: `widgets/modals/attendance_service_form.dart`.
- Logic: `helpers/attendance_stats.dart` — `attendanceSummary`,
  `sortAttendanceServices`, `attendanceTrendServices`,
  `attendanceHouseholdIds`. Pure and fully unit-tested
  (`test/attendance_stats_test.dart`).
- Model: `models/attendance_service_model.dart`, plus
  `attendanceServiceTypeKeys`.
- Repository/providers: `services/side_drawer/attendance_repository.dart`,
  `providers/side_drawer/attendance_providers.dart`.
- Data: `churches/{churchId}/services/{serviceId}`, capped at 260 documents
  on the client (five years of weekly services).
- Drawer: `DrawerMenuItem.attendance`, `adminOnly`, gated by
  `config.membersEnabled`.

The card reads date, then service type, then the subheader directly under
the type it qualifies, then the headcount/notes line. The marking sheet's
heading is `date · type · subheader`.

**Service types are stored as keys**, not display text — `sunday_worship`,
not "Sunday worship" — with a matching `attendance.service_type.<key>` entry
in `defaultChurchTextContents`. A church can rename "Midweek service" to
whatever it actually calls that gathering without rewriting history. Because
the key is built at runtime, `text_content_policy_test.dart` cannot check it
by reading the source; it skips interpolated keys and asserts this set
explicitly instead.

**The details form and the marking sheet write disjoint fields.**
`updateServiceDetails` never touches `present`, and `savePresent` never
touches the details, so saving one can't discard what someone else is doing
to the other.

## Deployment

`firestore.rules` gained a `churches/{churchId}/services/{serviceId}` match
(`allow read, write: if isChurchStaff(churchId)`). Deploy it with
**`firebase deploy --only firestore`** — never `--only firestore:rules`,
which prints "Deploy complete!" and releases nothing against this project's
array-form multi-database `firestore` config. The full story is in the
[decoupling migration doc](../architecture/user-church-decoupling-migration.md);
it cost hours once already.

**The screen cannot read anything until those rules are deployed** — rules
ship separately from the app binary, so a build can reach a backend that has
never heard of this collection. Verified on the emulator 2026-11-10: without
the deploy the listen fails `PERMISSION_DENIED`, which is why the screen has
an explicit failure state with a retry rather than an endless spinner.

Released to both `(default)` and `migrationv1` on 2026-11-10, confirmed by
diffing the live ruleset fetched from the Rules API against `firestore.rules`
rather than by trusting the CLI's success message.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| ATT-01 | Open the drawer as a church admin | "Attendance" appears between Studio and Equipment. |
| ATT-02 | Open the drawer as an approved member who is not an admin | No Attendance entry. Reading `churches/{id}/services` directly is also denied. |
| ATT-03 | Turn Members off for the church, reopen the drawer | Attendance disappears with it — it is marked against the member roster. |
| ATT-04 | Open Attendance before any service exists | Empty state with "Record a service"; all four statistics read "—", no trend chart. |
| ATT-05 | Record a service | The form closes and the marking sheet opens on that service, without a second tap. |
| ATT-06 | Try to pick a future date | The picker will not go past today; past dates up to five years back are allowed, for catching up on a backlog. |
| ATT-07 | Tap several members, then Save | One write. The list shows that count, and reopening the service shows the same people still marked. |
| ATT-08 | Tap one member of a family with household check-in on | The whole family is marked, and a snackbar says how many. |
| ATT-09 | Tap a marked member off, with household check-in on | Only that person is unmarked; their family stays present. |
| ATT-10 | Tap someone with no family set | Only they are marked. Nobody else without a family is touched. |
| ATT-11 | Use "Not yet marked" after marking half the roster | Only unmarked members remain listed; the tally still shows the full count. |
| ATT-12 | Search by name and by phone | Both match; clearing the box restores the whole roster. |
| ATT-13 | Record three services, leaving one active member out of all three | "Not seen for 3 services" shows 1 and is tinted as a warning. |
| ATT-14 | Record only two services, leaving someone out of both | The absence count is 0 — not enough history to call it a pattern. |
| ATT-15 | Record two services on the same date | Both appear, in a stable order across app restarts. |
| ATT-16 | Filter by service type | Only that type's services list; the statistics above stay church-wide. |
| ATT-17 | Edit a service's details while it has attendance | Date/type/subheader/headcounts/notes change; `present` is untouched. |
| ATT-18 | Delete a service | Confirmation first; the service and its attendance go, and the stats recompute. |
| ATT-19 | Open Attendance with `firestore.rules` not yet deployed | A failure message with Retry, not an endless spinner. |
| ATT-20 | Record a service with 12+ services already present | The trend chart shows the most recent 12, oldest on the left, newest highlighted. |
| ATT-21 | Record a service with a subheader, e.g. "2nd service" | The card shows it on its own line directly under the service type, and the marking sheet's heading reads `date · type · subheader`. |
| ATT-22 | Record a service leaving the subheader blank | The card shows the service type alone, with no empty line and no stray separator. |
| ATT-23 | Record two Sunday worships on one date with different subheaders | Both cards read "Sunday worship" but are told apart by their subheaders; opening each shows the right register. |
| ATT-24 | Open a service recorded before the subheader field existed | It reads as blank, not "null", and editing it can add one. |
