# Super Admin

## Purpose and authority

Super Admin is the global operations console. Access requires a matching
enabled document in `superAdmins`; it is not granted by church admin status.
On entry, eligible users choose normal church flow or super-admin mode.

## Church lifecycle

Super admin can:

- list/search enabled, disabled and pending churches;
- create/edit churches, branding, contact, initial pastor and optional
  Facebook/Instagram/YouTube links;
- enable/disable churches and configure feature flags;
- set a per-church Studio admin-count limit (3 or 5), enforced when a church
  admin tries to add a new Studio admin;
- review public registrations;
- review/delete/mark global feedback;
- open per-church Bible Learning setup and results.

Church creation seeds app config, default Home/For You sections, About, footer,
groups, Bible Swipe and pastor data. Account setup is optional for super-admin
creation. Public registration requires logged-in admin email equality and starts
pending. Its own button/app-bar title read "Register" (not "Register your
church" — that longer phrase is kept only for the invite link on
`ChurchPickerScreen` pointing here). The church contact/phone and admin
phone fields both validate as a 10-digit Indian mobile number
(`^[6-9]\d{9}$`, same convention as the signup profile step), and the
church email field is labelled "Church email" to distinguish it from the
admin's own email field on the same screen.

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
- Church service: `services/super_admin/super_admin_church_service.dart`
  (uploads the logo/pastor photo to Storage *before* any Firestore doc for
  the church exists — `storage.rules`' `isUnclaimedChurch(churchId)` allows
  a verified signed-in caller to write `churches/{churchId}/logo` and
  `.../pastorPhotos/{fileName}` while that's still true, since
  `isChurchStaff(churchId)` can never be satisfied yet at that point —
  there is no `config/app.admins` to be listed in, and a public registrant
  is not the super admin).
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
| SUPER-12a | Public registration (not a church admin or super admin yet) uploads the church logo and pastor photo | Succeeds — `storage.rules`' `isUnclaimedChurch` allows a verified signed-in caller to write those paths while the church doc doesn't exist yet; previously failed with `PERMISSION_DENIED`/403 since `isChurchStaff` can never be true for a brand-new public registrant. |
| SUPER-12b | Enter a church contact number or admin phone that isn't a valid 10-digit Indian mobile number | Blocked with the same "Enter a valid 10-digit phone number" message the signup profile step uses; digit-only input, capped at 10 characters. |
| SUPER-12c | Public self-registration completes the whole wizard (not just the logo/pastor-photo step) | The full creation batch (church doc, `config/app`, `about`, `bibleRandomSwipeVerses`, `footerSupport`, `pastor`, seeded `groups`, `home_sections`, `for_you_section`) succeeds via `firestore.rules`' `canBootstrapChurch` — every document in that batch is evaluated against pre-batch state, where `config/app` (which `isChurchStaff` needs to confirm admin status) doesn't exist yet even for the church's own creator; previously failed outright (`churches/{churchId}` itself could only ever be created by a super admin). |
| SUPER-13 | Large church list | Search/filter/tabs stay smooth and counts accurate. |
| SUPER-14 | Set admin-count limit (3/5) | `config/app.features.maxAdminCount` updates for only the target church; defaults to 5 (unlimited-of-5) when unset; lowering the limit below the current admin count does not remove existing admins, only blocks new additions in Studio. |
| SUPER-15 | Create/edit church with Facebook/Instagram/YouTube links | Links are optional, saved to `churches/{churchId}`, and match what a church admin later sees/edits from Settings (see [Navigation, Profile and Settings](navigation-profile-settings.md)). |

