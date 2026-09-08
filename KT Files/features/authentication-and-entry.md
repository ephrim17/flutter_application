# Authentication and Entry

## Purpose and scope

This feature owns onboarding, account creation, login, logout/switch-church,
password setup, forgot-password recovery, the person/church identity split,
approval gating, maintenance gating and the final handoff into a selected
church. See `KT Files/architecture/user-church-decoupling-migration.md` for
the full identity/membership design (`users/{uid}` vs
`churches/{cid}/members/{uid}`) — this doc covers the screens and flows built
on top of it.

## Roles

- Visitor: onboarding, registration, login and password recovery.
- Signed-in, no identity doc yet: profile step (`CompleteProfileScreen`).
- Signed-in, identity but no approved membership anywhere: the "My Churches"
  hub (`GuestShellScreen`) — covers never-requested, pending, declined
  (silently — a decline just deletes the membership row) and
  removed/left-only-church, per §5.3 of the migration doc.
- Approved member: church app (`ChurchTabScreen`), scoped to whichever church
  is currently selected.
- Super admin: normal-flow or super-admin-mode choice.

## Main flows

### Signup and entry gate

1. Visitor creates an account with email + password (Firebase Auth) —
   `CreateAuthAccountScreen`.
2. First launch after auth with no `users/{uid}` doc: `CompleteProfileScreen`
   captures name, phone, dob, gender only (§5.5 "signup" step) and writes the
   identity doc. This is a one-time step per person, not per church.
3. `AppEntry` (`screens/entry/app_entry.dart`) then routes on
   `myMembershipsProvider` — a `collectionGroup('members')` query, so it sees
   every church relationship the person has, approved or not:
   - No approved membership anywhere → `GuestShellScreen` (tabs: Bible, My
     Churches).
   - At least one approved membership → straight into `ChurchTabScreen` for
     the locally-selected/last-active church. The app does **not** force a
     picker screen for the common single-church case — see "Switching
     churches" below for how a person with more than one goes back to a
     chooser.

### Requesting access to a church

Once an identity exists, requesting access to any church never re-asks for
name/phone/dob/gender/address/marital status — those already live on
`users/{uid}`. `RequestChurchAccessScreen`
(`screens/entry/request_church_access_screen.dart`) shows the church and a
read-only summary of the person's own identity, and submits with one tap. It
guards against double-submission: it re-checks
`churches/{cid}/members/{uid}` immediately before writing and, if a row
already exists (e.g. a second tap, or a request made from another device in
the meantime), skips the write entirely rather than overwriting an
already-approved or already-pending row.

This replaces `LoginRequestScreen` for the self-service path.
`LoginRequestScreen` (`adminCreateMode: true`) remains unchanged as the
admin-create path — an admin-created member has no identity doc, so the
admin form still has to supply everything (§9.3 of the migration doc).

The `GuestShellScreen`'s "My Churches" tab has three sections:

| Section | Contents |
|---|---|
| Your churches | Approved memberships — tap enters that church directly. Only shown once at least one exists (relevant to someone approved in one church while still pending in another; see the entry-gate rule above for why an approved-everywhere-except-here layout doesn't apply to the common case). |
| Your requests | Pending memberships. |
| Browse churches | Every other church, with a "Request access" button. Churches already requested or joined are excluded here — they show up in the two sections above instead. |

Church Tree (global) learning modules are **not** shown in this hub — they
stay reachable inside any joined church (§5.6 of the migration doc covers the
two learning tracks).

### Switching churches / logging out

Inside a church (Settings screen, Account section):

- **Switch church** — shown only when the person has more than one church
  relationship. Clears the locally selected church and returns to
  `SelectChurchScreen` ("Your churches" / "Other churches") without ending
  the Firebase session.
- **Logout** — always shown. Fully signs out of Firebase Auth and returns to
  the login screen. (Previously this tile was labelled "Logout" but only
  cleared the local church selection without ending the session — fixed as
  part of this pass; the sign-out call was missing.)

### Forgot password with email code

1. User enters a valid normalized email.
2. `requestPasswordResetCode` creates a cryptographically random six-digit
   code and emails it through configured SMTP.
3. The server stores only a keyed code hash in
   `passwordResetChallenges/{opaqueHmacId}`. It does not store the email.
4. Code lifetime is 10 minutes; resend cooldown is 60 seconds; maximum is five
   requests per hour and five verification attempts.
5. A valid code returns a random, hashed-at-rest, one-time reset session.
6. The in-app reset screen enforces at least eight characters, one uppercase
   letter and one number.
7. `completePasswordReset` updates Firebase Auth, revokes refresh tokens and
   deletes the challenge.

Unknown accounts receive the same successful request response as known
accounts to avoid revealing registered emails. First-time admin account setup
continues to use the Firebase action-link email flow.

## Technical map

- Screens: `screens/entry/` — `app_entry.dart` (gate),
  `complete_profile_screen.dart` (signup step),
  `request_church_access_screen.dart` (self-service request access),
  `login_request_screen.dart` (admin-create path, `adminCreateMode: true`),
  `login_entry_screen.dart`, `forgot_password_screen.dart`,
  `password_reset_code_screen.dart`, `reset_password_screen.dart`.
  `screens/personal/guest_shell_screen.dart` (no-approved-membership hub).
  `screens/select-church-screen.dart` (multi-church chooser, reached from
  Settings > Switch church, not from the entry gate).
- Repositories: `services/firestore/firestore_authentication.dart`
  (`requestAccess`, shared by both the admin form and the self-service
  screen), `services/user_identity_repository.dart` (identity doc lifecycle).
- Shared logic: `helpers/self_signup_membership_helper.dart` — derives
  self-signup category/family id from identity fields; used by both
  `login_request_screen.dart`'s member-mode path and
  `request_church_access_screen.dart` so they can't drift.
- Providers: `providers/authentication/firebaseAuth_provider.dart`,
  `providers/user_provider.dart` (`userIdentityProvider`,
  `myMembershipsProvider`, `currentMembershipProvider`).
- Backend: `requestPasswordResetCode`, `verifyPasswordResetCode`,
  `completePasswordReset`, and `sendPasswordResetSmtpEmail`.
- Local onboarding state: SharedPreferences `onboarding_completed`.

## Invariants and failure behaviour

- Never generate or verify reset codes on the client.
- Never log codes, reset tokens, passwords or SMTP secrets.
- Do not expose whether an email is registered.
- A consumed/expired reset session cannot be reused.
- A failed request leaves the user on the current step with a retryable error.
- Async entry screens must not use `context` or `ref` after unmount.
- Self-service request-access never re-writes an existing membership doc —
  always check-before-write, never blind `.set()`, so a duplicate tap or a
  race with another device can't reset an approved row back to pending.
- `role` on a membership is never an authorization source (§9.1 of the
  migration doc) — the entry gate and all rules key off `approved`, the
  church admin allowlist, or the `superAdmins` record.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| AUTH-01 | Fresh install | Onboarding appears once; completion persists after relaunch. |
| AUTH-02 | Valid login for approved member | Correct selected church opens without an unmounted-provider lifecycle error. |
| AUTH-03 | Wrong password/disabled user | Localized error; no membership data shown. |
| AUTH-04 | Signed in, no identity doc yet | Profile step opens; submitting writes `users/{uid}` and proceeds. |
| AUTH-05 | Signed in, identity but no approved membership anywhere | My Churches hub opens (Bible + My Churches tabs, no Learning tab). |
| AUTH-06 | Pending membership | Shows under "Your requests" in the hub; church content is inaccessible. |
| AUTH-07 | Approved in one church, pending in another | Hub shows both "Your churches" (tap enters) and "Your requests"; approved-anywhere still auto-enters on next cold start. |
| AUTH-08 | Request access as an existing identity | No name/phone/dob/etc. fields shown; one tap submits; church admin sees a normal pending request. |
| AUTH-09 | Request access twice (double tap, or a second device mid-request) | Second attempt does not overwrite the first row or reset an approved membership back to pending. |
| AUTH-10 | Browse churches list | Already-requested/joined churches do not appear with a "Request access" button. |
| AUTH-11 | Switch church with only one church | "Switch church" tile is hidden in Settings. |
| AUTH-12 | Switch church with 2+ churches | Tile visible; tapping opens `SelectChurchScreen` without ending the session. |
| AUTH-13 | Logout | Firebase session actually ends; relaunch requires signing in again. |
| AUTH-14 | Maintenance mode as member/admin | Member is blocked; configured church admin can enter. |
| AUTH-15 | Request password code for known account | Exactly one six-digit email arrives and verification screen opens. |
| AUTH-16 | Request code for unknown account | UI response matches known account; no account-existence hint. |
| AUTH-17 | Wrong code repeatedly | Attempts decrement; fifth failure blocks verification. |
| AUTH-18 | Expired code | Verification fails and requests a new code. |
| AUTH-19 | Resend before/after cooldown | Early resend disabled; later resend invalidates prior code and sends a new one. |
| AUTH-20 | Valid code and valid new password | Reset screen opens, password changes, old password fails and new password logs in. |
| AUTH-21 | Weak/mismatched password | Inline validation prevents server submission. |
| AUTH-22 | Reuse reset token/code | Rejected after successful password update. |
| AUTH-23 | Network loss on each step | No crash/duplicate email; retry is possible. |
| AUTH-24 | First-time admin setup email | Existing action link still opens and completes setup. |

Security integration tests should call the deployed/emulated endpoints directly
for invalid method, malformed email/code, expired session, brute-force limit and
token replay cases.
