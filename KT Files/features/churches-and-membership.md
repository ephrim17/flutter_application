# Churches and Membership

## Purpose

Users can discover churches, belong to multiple churches, request access and
operate within one selected church. Public church registration creates a
pending church that requires super-admin approval.

## User flows

- **Your Churches** lists approved memberships only (`approved == true`).
- **Pending Approval** lists churches the user has requested access to but
  isn't approved for yet — tapping one reopens `RequestPendingScreen` for
  that church instead of letting them submit a duplicate request.
- **Other Churches** lists discoverable churches the user has not joined or
  requested access to.
- Both lists render each church with the same card design (pastor photo,
  address, Facebook/Instagram/YouTube badges) that used to live on the
  standalone Discover tab — Discover was removed once this screen covered
  the same ground.
- Selecting an existing approved membership enters that church.
- Selecting another church starts request access and creates
  `churches/{churchId}/users/{uid}`.
- Your Churches, Pending Approval and Other Churches are driven by live
  `StreamProvider`s (`churchesProvider`, `myMembershipsProvider`), so a new
  request, an approval, or leaving a church updates all three sections
  immediately with no manual refresh.
- The church-picker app bar shows an account icon next to the logout action.
  A red badge appears while the signed-in user's global `profileComplete`
  flag is `false`; tapping the icon opens the Edit Profile sheet directly
  (same sheet as Settings → Profile → Edit Profile).
- Church registration requires the admin email to match the currently signed-in
  email. Church and admin recipients receive a welcome/pending-review email;
  super-admin email addresses are not displayed in the registration UI.
- Super admin enables or disables the church after review.

## Business rules

- All profile/membership writes are scoped to the chosen `churchId` and Auth
  `uid`.
- Approval is church-specific; approval in Church A grants nothing in Church B.
- A bootstrap rule may auto-approve the first matching configured admin when a
  church has no users and exactly one admin email is configured.
- A disabled church or `superAdminDisabled` config blocks normal access.
- Selected church can be restored locally, but server membership/configuration
  remains authoritative.
- `isAdminProvider`/`churchAdminProvider` (client) check ONLY the signed-in
  email against that church's `config/app.admins` — deliberately NOT
  super-admin-aware, unlike the backend's `isChurchStaff(churchId) =
  isChurchAdmin(churchId) || isSuperAdmin()`. Being a super admin grants
  backend read/write rights on every church (a platform-moderation
  capability enforced in `firestore.rules`), but must never silently hand
  out per-church admin UI (edit/approve members, extended info, church
  groups) for a church the person isn't actually responsible for. Tried
  making `isAdminProvider` super-admin-aware once; confirmed as a real
  regression (a super admin got full admin actions on a church they were
  never added to) and reverted.

## Technical map

- Screens: `select-church-screen.dart`, `entry/login_request_screen.dart`,
  `entry/create_auth_account_screen.dart`, pending approval widget.
- Card widget: `widgets/church_discovery_card.dart`.
- Providers: `select_church_provider.dart`, `church_provider.dart`,
  `user_provider.dart`.
- Services: `church_repository.dart`, `church_user_repository.dart`,
  `firestore_authentication.dart`.
- Backend: `queuePublicChurchRegistrationWelcome`,
  `sendQueuedSuperAdminMail`.
- Data: `churches/{churchId}`, `churches/{churchId}/users/{uid}`, global
  `users/{uid}`, and `churches/{churchId}/config/app`.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| CHURCH-01 | User belongs to A but not B | A appears under Your Churches; B under Other Churches. |
| CHURCH-02 | Select approved membership | Correct church config/user loads with no data from previous church. |
| CHURCH-03 | Request access to B | Pending B membership is created; A membership is unchanged. |
| CHURCH-04 | Admin approves/declines member | Access changes only for the targeted church/user. |
| CHURCH-05 | First configured admin joins empty church | Auto-approval occurs only when every bootstrap condition matches. |
| CHURCH-06 | Register church with different admin email | Form blocks submission and keeps current-user email authoritative. |
| CHURCH-07 | Successful public registration | Church is pending/hidden; church/admin welcome emails arrive with support guidance and no admin-address list. |
| CHURCH-08 | Super admin enables/disables church | Enabled church becomes accessible; disabled church shows block message. |
| CHURCH-09 | Switch A -> B -> A | All feeds, members, Studio data, topics and badges follow active church. |
| CHURCH-10 | Deleted/invalid cached church | App returns safely to selection. |
| CHURCH-11 | Duplicate request or double-tap | One membership/registration is created. |
| CHURCH-12 | Network interruption | No half-created visible church; recoverable error is shown. |
| CHURCH-13 | Super admin (not listed in that church's `config/app.admins`) opens Members screen for that church | Plain member-level UI is shown — no edit/approve, extended info, or church groups sections, even though the backend would allow the writes. |
| CHURCH-14 | Staff approves a self-registered (request-access) pending member | Approval succeeds; no `PERMISSION_DENIED` from the display-field-cache guard. |
| CHURCH-15 | User has a pending request to church B while approved in church A | A shows under Your Churches; B shows under Pending Approval, not Your Churches or Other Churches. |
| CHURCH-16 | Tap a church under Pending Approval | Opens `RequestPendingScreen` for that church; no duplicate request is submitted. |
| CHURCH-17 | Request/approve/leave a church while the picker screen is open | Your Churches/Pending Approval/Other Churches reorder live with no manual refresh or re-entry to the screen. |
| CHURCH-18 | Sign in with `profileComplete: false` / `true` | Account icon in the church-picker app bar shows/hides the red badge to match; tapping it opens Edit Profile. |

