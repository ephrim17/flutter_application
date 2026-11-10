# Church Admin Dashboard

## Purpose and access

Dashboard gives church admins operational insight into enabled content,
members, engagement, prayers, announcements, events and Bible Learning results.
It is present only when the user is a church admin and `dashboardEnabled` is
true.

## Current panels

- Feature/configuration status overview.
- Special days.
- Church insights/health indicators (the removed Content Gaps block must not
  return).
- Daily Faith updates and seven-day loop history.
- Member snapshot: a donut chart with a colour legend, joins and streaks.
- Prayer pulse.
- Announcement and event summaries.
- Bible Learning results/updates as exposed by the super-admin learning views.

**The member snapshot is the chart and its legend, nothing more.** Each
segment's colour, label, count and share — the chart already carries the
total in its centre. The per-segment panel that used to sit below it (the
selected segment restated, a families list, and member names) was removed on
2026-11-10: it repeated what the legend says and pushed the chart off screen.

Gender is the one view that drills down, and it does so by navigating to a
separate filtered page with search rather than embedding a list under the
chart.

The financial dashboard is intentionally absent.

## Technical map

- UI: `screens/dashboard/` with view models and view components.
- Providers: `providers/dashboard/`.
- Aggregates: `services/dashboard/dashboard_metrics_repository.dart` and
  `churches/{churchId}/dashboard_metrics`.
- Backend: `rebuildChurchDashboardMemberMetrics`.

**The member snapshot's four views are computed on the client**, from the
member list the dashboard already loads for birthdays and anniversaries.
`helpers/dashboard_member_stats.dart` holds all of it — gender, age, family
mode, solemnized, the families panel and the headline counts — as pure
functions over `List<ChurchMembership>`, covered by
`test/dashboard_member_stats_test.dart`.

They moved there on 2026-11-10, after the gender view read **"Unknown, 100%"
for every church**. The cause was in the Cloud Function: it adapted the
stored `members/{uid}` shape onto the field names its bucket logic read, and
mapped `displayName`, `displayDob` and `joinedAt` but not `displayGender`. A
missing alias is not an error anywhere — it reads as `undefined`, so the
"neither male nor female" bucket silently collected all 18 of tnbm's members
while the drill-down screen, filtering the same live list, stayed correct.

The deeper problem was not the typo but the shape: a stored aggregate of a
list the screen already holds is a second answer to one question, and the
two can disagree. Deriving from the list removes that class of bug —
nothing goes stale, nothing needs backfilling, and changing a bucket
definition is no longer a deploy.

**What stays server-side, and why:** the streak numbers
(`activeStreakMembersCount`, `membersWith7PlusCount`, `activeStreakRate`,
`topStreakValue`, `topStreakMember`). They read `dayStreak` from
`users/{uid}`, which `firestore.rules` exposes only to that user
(`isSelf(uid)`), and `mirrorMemberDirectory` does not copy it into the
church. No client can aggregate them. The join history
(`recentJoinCount*`, `joinedThisYear`, `recentMembers`, `firstRecordedAt`)
is also still read from the stored document.

**Dead stored fields.** `genderBuckets`, `ageBuckets`, `familyModeBuckets`,
`solemnizedBuckets`, `familyBuckets` and the composition counts
(`memberCount`, `approvedMembers`, `pendingApprovals`, `familyCount`,
`individualCount`, `membersWithGroups`, `groupParticipationRate`) are no
longer read by anything. The function still writes them; removing that is a
follow-up, not a fix. Do not reintroduce a reader for them.

**Two rules that came out of this.** Bucket **ids** (`male`, `seniors`,
`not_solemnized`) are the stable key — colours, the drill-down's filter and
analytics all use the id, and labels resolve through
`dashboard.<mode>_bucket.<id>`. The previous code switched colours on the
English label, so any church running in another language got grey for every
segment. And the chart hands the drill-down **its own bucket's members**
rather than letting that screen re-derive them; it used to match
`displayGender` against the segment's label, so "Unknown" compared against
the literal string `"unknown"` and listed nobody.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| DASH-01 | Member/admin/flag combinations | Dashboard appears only for enabled eligible admin. |
| DASH-02 | Empty/new church | Useful empty metrics; no Content Gaps or finance panel. |
| DASH-03 | Member create/update/delete | Counts/percentages rebuild and match source members. |
| DASH-04 | Tap gender bucket | Separate filtered screen shows all correct members and supports search. |
| DASH-16 | Switch between all four views | Each shows the chart and its legend only — no panel underneath restating the selected segment, listing families, or naming members. |
| DASH-11 | Compare each chart bucket against its drill-down | The counts match, because the drill-down lists the bucket's own members rather than re-deriving them. Verified on the emulator 2026-11-10: Male 14 in the chart, 14 in the list. |
| DASH-12 | Add a member with a gender, then reopen the dashboard | The gender view moves them into Male or Female, not Unknown. |
| DASH-13 | Add a member with no gender on file | They appear under Unknown, Unknown never reaches 100% while others have a gender, and tapping Unknown lists them. |
| DASH-14 | Edit a member, then return to the dashboard | Every bucket and headline count reflects the edit immediately — they are grouped from the live list, with no trigger to wait for. |
| DASH-15 | Open the member snapshot in a non-English text content set | Segment labels translate; segment colours stay correct, because colour is keyed off the bucket id, not the label. |
| DASH-05 | Special days/joins/streaks | Counts match local-date source records and singular/plural captions use correct grammar. |
| DASH-06 | Daily Faith activity | Today and seven-day panels match progress docs. |
| DASH-07 | Prayer/announcement/event updates | Relevant dashboard summaries update without wrong-church data. |
| DASH-08 | Learning results | Attempts/pass rates/latest results match stored final exams. |
| DASH-09 | Disabled content feature | Status panel shows correct disabled state without broken navigation. |
| DASH-10 | Large data/loading/error | Panels remain smooth, independently recoverable and non-overflowing. |
