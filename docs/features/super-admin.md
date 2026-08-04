# Super Admin

## Purpose and authority

Super Admin is the global operations console. Access requires a matching
enabled document in `superAdmins`; it is not granted by church admin status.
On entry, eligible users choose normal church flow or super-admin mode.

## Church lifecycle

Super admin can:

- list/search enabled, disabled and pending churches;
- create/edit churches, branding, contact and initial pastor;
- enable/disable churches and configure feature flags;
- review public registrations;
- review/delete/mark global feedback;
- open per-church Bible Learning setup and results.

Church creation seeds app config, default Home/For You sections, About, footer,
groups, Bible Swipe and pastor data. Account setup is optional for super-admin
creation. Public registration requires logged-in admin email equality and starts
pending.

Super-admin change emails end with scenario-appropriate warm copy for new,
enabled and disabled churches. Registration UI does not enumerate super-admin
email addresses.

## Bible Learning authority

Only super admin manages global modules, church learning enablement,
inheritance, hiding, ordering, church-only modules, independent custom copies
and church results. See [Bible Learning](bible-learning.md).

## Technical map

- UI: `screens/super_admin/`.
- Authorization: `providers/authentication/super_admin_provider.dart`.
- Church service: `services/super_admin/super_admin_church_service.dart`.
- Backend email: `sendQueuedSuperAdminMail`,
  `queuePublicChurchRegistrationWelcome`.
- Global data: `superAdmins`, `churches`, `globalFeedback`, `learning_modules`.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| SUPER-01 | Enabled/disabled/non-super account | Only enabled matching super admin enters console. |
| SUPER-02 | Choose normal vs super mode | Choice persists for user session and switches safely. |
| SUPER-03 | Create church | Complete seed set, files and feature defaults are created once. |
| SUPER-04 | Duplicate ID/email | Creation is blocked before partial bootstrap. |
| SUPER-05 | Optional account setup | Enabled path creates/sends setup; disabled path skips Auth but stores intended admin. |
| SUPER-06 | Review public registration | Pending church is hidden until approval; enable/disable state is correct. |
| SUPER-07 | Edit feature flags | Only target church changes and member/admin navigation updates. |
| SUPER-08 | Enable/disable notification email | Correct recipients/content/warm ending; no super-admin address list in UI. |
| SUPER-09 | Feedback review/delete | Status/delete updates once with confirmation. |
| SUPER-10 | Learning setup/results | Church customization is isolated; results match attempts. |
| SUPER-11 | Direct privileged call as non-super admin | Backend/rules reject it. |
| SUPER-12 | Failed image/upload/bootstrap | Error is recoverable; no misleading complete church remains. |
| SUPER-13 | Large church list | Search/filter/tabs stay smooth and counts accurate. |

