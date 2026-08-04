# Churches and Membership

## Purpose

Users can discover churches, belong to multiple churches, request access and
operate within one selected church. Public church registration creates a
pending church that requires super-admin approval.

## User flows

- **Your Churches** lists memberships found under each church's `users` data.
- **Other Churches** lists discoverable churches the user has not joined.
- Selecting an existing approved membership enters that church.
- Selecting another church starts request access and creates
  `churches/{churchId}/users/{uid}`.
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

## Technical map

- Screens: `select-church-screen.dart`, `entry/login_request_screen.dart`,
  `entry/create_auth_account_screen.dart`, pending approval widget.
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

