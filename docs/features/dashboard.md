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
- Member snapshot, joins, streaks, gender distribution and family insights.
- Prayer pulse.
- Announcement and event summaries.
- Bible Learning results/updates as exposed by the super-admin learning views.

Gender summary boxes navigate to a separate filtered page containing all male
or female members rather than embedding the list below the chart.

The financial dashboard is intentionally absent.

## Technical map

- UI: `screens/dashboard/` with view models and view components.
- Providers: `providers/dashboard/`.
- Aggregates: `services/dashboard/dashboard_metrics_repository.dart` and
  `churches/{churchId}/dashboard_metrics`.
- Backend: `rebuildChurchDashboardMemberMetrics`.
- Learning reporting: `learning_results_admin_screen.dart` and church results.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| DASH-01 | Member/admin/flag combinations | Dashboard appears only for enabled eligible admin. |
| DASH-02 | Empty/new church | Useful empty metrics; no Content Gaps or finance panel. |
| DASH-03 | Member create/update/delete | Counts/percentages rebuild and match source members. |
| DASH-04 | Tap gender bucket | Separate filtered screen shows all correct members and supports search. |
| DASH-05 | Special days/joins/streaks | Counts match local-date source records. |
| DASH-06 | Daily Faith activity | Today and seven-day panels match progress docs. |
| DASH-07 | Prayer/announcement/event updates | Relevant dashboard summaries update without wrong-church data. |
| DASH-08 | Learning results | Attempts/pass rates/latest results match stored final exams. |
| DASH-09 | Disabled content feature | Status panel shows correct disabled state without broken navigation. |
| DASH-10 | Large data/loading/error | Panels remain smooth, independently recoverable and non-overflowing. |

