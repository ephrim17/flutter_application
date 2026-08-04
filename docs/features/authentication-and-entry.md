# Authentication and Entry

## Purpose and scope

This feature owns onboarding, account creation, login, logout, password setup,
forgot-password recovery, approval gating, maintenance gating and the final
handoff into a selected church.

## Roles

- Visitor: onboarding, registration, login and password recovery.
- Authenticated user without membership: church selection/request access.
- Pending member: pending-approval screen only.
- Approved member: church app.
- Super admin: normal-flow or super-admin-mode choice.

## Main flows

### Login

1. User selects a church context and enters email/password.
2. Firebase Auth validates credentials.
3. The app resolves `churches/{churchId}/users/{uid}`.
4. `AppEntry` routes according to approval, church status and maintenance mode.

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

- Screens: `screens/entry/`, especially `app_entry.dart`,
  `login_entry_screen.dart`, `forgot_password_screen.dart`,
  `password_reset_code_screen.dart`, `reset_password_screen.dart`.
- Repository: `services/firestore/firestore_authentication.dart`.
- Provider: `providers/authentication/firebaseAuth_provider.dart`.
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

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| AUTH-01 | Fresh install | Onboarding appears once; completion persists after relaunch. |
| AUTH-02 | Valid login for approved member | Correct selected church opens. |
| AUTH-03 | Wrong password/disabled user | Localized error; no membership data shown. |
| AUTH-04 | Authenticated user without membership | Church selection opens. |
| AUTH-05 | Pending membership | Pending screen opens; church content is inaccessible. |
| AUTH-06 | Maintenance mode as member/admin | Member is blocked; configured church admin can enter. |
| AUTH-07 | Request password code for known account | Exactly one six-digit email arrives and verification screen opens. |
| AUTH-08 | Request code for unknown account | UI response matches known account; no account-existence hint. |
| AUTH-09 | Wrong code repeatedly | Attempts decrement; fifth failure blocks verification. |
| AUTH-10 | Expired code | Verification fails and requests a new code. |
| AUTH-11 | Resend before/after cooldown | Early resend disabled; later resend invalidates prior code and sends a new one. |
| AUTH-12 | Valid code and valid new password | Reset screen opens, password changes, old password fails and new password logs in. |
| AUTH-13 | Weak/mismatched password | Inline validation prevents server submission. |
| AUTH-14 | Reuse reset token/code | Rejected after successful password update. |
| AUTH-15 | Network loss on each step | No crash/duplicate email; retry is possible. |
| AUTH-16 | First-time admin setup email | Existing action link still opens and completes setup. |

Security integration tests should call the deployed/emulated endpoints directly
for invalid method, malformed email/code, expired session, brute-force limit and
token replay cases.

