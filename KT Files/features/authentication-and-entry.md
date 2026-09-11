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

- Visitor: onboarding, then an explicit sign-in/sign-up choice
  (`AuthChoiceScreen`), registration, login and password recovery.
- Signed-in, no identity doc yet: profile step (`CompleteProfileScreen`) —
  reachable in the normal flow only as a resume case (see "Signup and entry
  gate" below); the profile step in a fresh sign-up runs *before* any
  Firebase account exists.
- Signed-in, identity exists but not email-verified: `EmailOtpVerificationScreen`.
- Signed-in, identity but no approved membership anywhere: `SelectChurchScreen`
  — covers never-requested, pending, declined (silently — a decline just
  deletes the membership row) and removed/left-only-church, per §5.3 of the
  migration doc. There is no separate guest hub; a pending membership shows
  a "still pending" message rather than entering.
- Approved member: church app (`ChurchTabScreen`), scoped to whichever church
  is currently selected.
- Super admin: normal-flow or super-admin-mode choice.

## Main flows

### Signup and entry gate

1. Visitor sees `AuthChoiceScreen` — an explicit "Sign In" / "Sign Up"
   choice, not a guess. There is no email-enumeration workaround needed
   here (the older combined screen used to guess sign-in vs. create-account
   from context and self-correct from the resulting Firebase error, since
   `fetchSignInMethodsForEmail` is no longer reliable) because the person
   states their intent up front by which button they tap.
   - **Sign In** → `SignInScreen` (email + password, forgot-password link).
     On success, `AppEntry` takes over as normal.
   - **Sign Up** → `CompleteProfileScreen`, but *before* any Firebase
     account exists (see next point), then `CreateAccountScreen`
     (email + password + confirm). `SignInScreen` shows an explanatory
     message on `user-not-found` but has no "Register" link — its `AppBar`'s
     automatic back button (it's always pushed directly on `AuthChoiceScreen`)
     is the only way back to Sign Up. `CreateAccountScreen` self-corrects
     automatically on `email-already-in-use`: an explanatory message, then
     straight to `SignInScreen` pre-filled with that email (no tap needed);
     it also keeps its own "Already have a Church Tree account? Login" link
     for anyone who wants to switch before hitting that error.
     `CreateAuthAccountScreen` (the old combined screen) still exists but is
     now admin-create-member only (`login_request_screen.dart`'s companion
     for creating a member's Firebase account, `members_screen.dart`'s only
     remaining caller) — a single email-only screen, unaffected by any of
     this since it never collected a password from the admin's own session.
2. `CompleteProfileScreen` captures name, phone, dob, gender only (§5.5
   "signup" step). It has two call shapes sharing one form:
   - **Normal sign-up** (from `AuthChoiceScreen`): no Firebase account
     exists yet, so there's no `uid` to write against — submitting just
     hands the collected fields (`ProfileDraft`) to `CreateAccountScreen`,
     which creates the account and writes `users/{uid}` (draft + email) in
     one step. This is why profile setup happens *before* email/password
     now, not after.
   - **Resume** (`AppEntry`, identity doc missing but a Firebase account
     already exists — e.g. a sign-up abandoned between account creation and
     profile submission on an older flow, or an interrupted retry):
     submitting writes the identity doc directly using the already-signed-in
     user. Its own screen rather than a step inside a bigger form is what
     makes this resume possible either way.
   `CompleteProfileScreen` has no "Login" link of its own — its `AppBar`
   exists only for the automatic back button, which in the normal sign-up
   shape returns to `AuthChoiceScreen` (always pushed directly on top of
   it, thanks to `goToSignUp`'s stack-collapsing) for anyone who wants
   Sign In instead. In the resume shape there's no route beneath it to pop
   to, so no back arrow shows at all — the person is already signed in
   there, so "go back to Sign In" would not mean anything.
   Phone is India-only: the field shows a fixed, non-editable "+91" prefix
   and accepts exactly ten digits (`^[6-9]\d{9}$`, same pattern
   `settings_screen.dart` already used); the stored `phone` value is still
   the bare ten digits, no country code — the prefix is presentation-only.
3. Identity exists but `emailVerified` is still false:
   `EmailOtpVerificationScreen` sends a six-digit code to the account's own
   email on mount (there's no earlier screen to trigger it from, unlike
   forgot-password) and blocks entry until it's verified — see "Signup email
   verification" below. Password-based sign-in itself is unchanged; this is
   an additional one-time gate after profile setup, not a replacement for it.
   `emailVerified` defaults to true everywhere except
   `UserIdentityRepository.createIdentity` (the only place a brand-new
   identity doc is ever created), which writes it false explicitly — so
   this only ever gates someone going through sign-up for the first time.
   A person who already had an account before this gate existed, or whose
   identity doc was seeded directly by an admin action (e.g.
   `attachFirebaseAuthToMember`), has no `emailVerified` field at all and is
   treated as already verified — they are never sent back through a check
   that didn't exist when their account was made.
4. `AppEntry` (`screens/entry/app_entry.dart`) then routes on
   `myMembershipsProvider` — a `collectionGroup('members')` query, so it sees
   every church relationship the person has, approved or not:
   - No approved membership anywhere → `SelectChurchScreen`.
   - At least one approved membership, and a church is resolvable (local
     storage on this device, or `lastActiveChurchId` on the identity from a
     previous pick on any device) → straight into `ChurchTabScreen` for
     that church. No picker for a returning user, single-church or not.
   - At least one approved membership, but nothing resolvable yet (the
     very first time this account ever reaches an approved church, or
     their remembered church stopped being approved) → `SelectChurchScreen`,
     so they pick rather than the app guessing. Picking an approved one sets
     `lastActiveChurchId`, so every later launch — this device or a new one
     — resumes it directly; the picker is a one-time thing per account, not
     a permanent hub. See "Switching churches" below for how to reach it
     deliberately later.

### Switching between Sign In and Sign Up

Two helpers in `auth_navigation.dart` — `goToSignIn(context, {initialEmail})`
and `goToSignUp(context)` — are the only way anything jumps between the
Sign In and Sign Up sides of this flow; nothing builds a raw
`MaterialPageRoute` to `SignInScreen` or `CompleteProfileScreen` directly.
Both first call `popUntil((route) => route.isFirst)` (collapsing back to
`AuthChoiceScreen`, which is always the base of this navigator — it's
rendered inline by `AppEntry`, itself always reached via
`pushAndRemoveUntil` when signed out) and then push the target fresh. This
keeps the stack at a fixed depth of two no matter how many times someone
switches sides — pushing plain `Navigator` routes back and forth previously
let the stack grow by one route every time.

Callers: `AuthChoiceScreen`'s two buttons (the normal entry points), and
`CreateAccountScreen`'s "Already have a Church Tree account? Login" link
and its automatic `email-already-in-use` redirect. `SignInScreen` and
`CompleteProfileScreen` do **not** call either helper and have no
reciprocal link of their own — each relies on its `AppBar`'s automatic back
button (both are always pushed directly on `AuthChoiceScreen`) to switch
sides, rather than a visible "Register"/"Login" toggle. The one link in
this whole area that isn't about switching sides at all is `SignInScreen`'s
forgot-password link (`ForgotPasswordScreen` stays a normal push).

`SelectChurchScreen` itself is feed-first, not a church list — its body is
`GlobalFeedListView` (the cross-church feed, inline, tap a post to open
`GlobalFeedFullScreenViewer` at that post — the same Reels-style swipeable
viewer `CommunityFullScreenViewer` uses, sharing its `CommunityViewerPageView`,
but global-only: no "Your Church" segment and no create-post action, since
posting stays church-scoped from inside Community). "Churches" is a second
bottom tab (`AppBottomTabBar`, mirroring `ChurchTabScreen`'s own tab bar)
whose body is `ChurchPickerScreen` — "Your Churches" / "Pending Approval" /
"Other Churches" — for anyone who actually wants to pick or request a
church rather than just browse the feed. The app bar's title always reads
the fixed app brand name (`guest_shell.title`, "Church Tree") regardless of
which of the two tabs is active, and its super-admin/account/logout actions
stay visible across both tabs too. `ChurchPickerScreen` has no
`Scaffold`/`AppBar` of its own and is never pushed — it's purely this tab's
body, so there is no back button involved at all here, only the tab bar.
`SelectChurchScreen` itself is always root-level (no back button in any of
its entry points).

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

A non-auto-approved submission (and revisiting a church where a pending row
already exists, from either `RequestChurchAccessScreen` or
`ChurchPickerScreen`) lands on `RequestPendingScreen`
(`screens/entry/request_pending_screen.dart`) instead of a snackbar. It has
one action, "Notify me when approved": requests OS notification permission
(`handleNotificationSetup`) and sets `notifyOnApproval: true` on the
membership doc. `notifyMemberOnApproval` (functions, a `members/{memberId}`
write trigger) fires once on the `approved` false->true edge when that flag
is set — sends a direct FCM push (`resolveDeviceTokensByUid`, not a topic,
since the person isn't a church member yet to subscribe to one) and queues
an email through the `mail` collection (the same Trigger-Email-extension
pattern `queuePublicChurchRegistrationWelcome` already uses). Nobody who
didn't tap the button gets contacted.

This replaces `LoginRequestScreen` for the self-service path.
`LoginRequestScreen` (`adminCreateMode: true`) remains unchanged as the
admin-create path — an admin-created member has no identity doc, so the
admin form still has to supply everything (§9.3 of the migration doc).

`ChurchPickerScreen` (`SelectChurchScreen`'s "Churches" tab body) has three
sections — see [Churches and Membership](churches-and-membership.md) for the
full behaviour and provider details (`userChurchesProvider` /
`pendingChurchesProvider`, both derived live from `churchesProvider` and
`myMembershipsProvider` so they update immediately on request/approve/leave,
with no manual refresh):

| Section | Contents |
|---|---|
| Your Churches | Every church the person has an *approved* membership row in. Tapping one enters it. |
| Pending Approval | Every church with a membership row that isn't approved yet. Tapping one reopens `RequestPendingScreen` instead of entering. |
| Other Churches | Every remaining church, reachable via "Request access". |

Church Tree (global) learning modules are **not** shown for someone with no
approved membership — they stay reachable inside any joined church (§5.6 of
the migration doc covers the two learning tracks).

### Switching churches / logging out

Once inside a church there is no back button out of it — `ChurchTabScreen`
wraps itself in `PopScope(canPop: false)`, and every route that enters a
church (`SelectChurchScreen`, `ChurchTabScreen`'s own switcher, logout)
does so with `pushAndRemoveUntil`, never
`pushReplacement`, so the stack is always exactly one route deep once
inside. The only ways out are deliberate, and deliberately different for
two different needs:

- **Switch to a church you're already in** — tap the church name/logo in
  `ChurchTabScreen`'s app bar (styled with a small chevron so it reads as
  tappable). Opens `ChurchQuickSwitcherSheet`, a small bottom sheet listing
  only this person's *approved* memberships (not the full church
  directory — there is nothing to request access to here, so no
  `ChurchPickerScreen` tab, no feed). Tapping one switches immediately;
  `ChurchTabScreen` performs the actual switch after the sheet closes
  (`pushAndRemoveUntil`, so the church being left never lingers
  underneath) rather than the sheet navigating from its own
  about-to-be-popped context. Does not end the Firebase session.
- **Register for a church you haven't joined** — Settings > "Register for
  another church" opens `SelectChurchScreen` (Home tab first, with a
  "Churches" tab for Your churches / Other churches) with the whole stack
  cleared (`pushAndRemoveUntil`) — this screen is always root-level, in
  every entry point, so there is no back button here either; leaving it
  means either entering an approved church or starting a request. This is
  the only current way to reach `RequestChurchAccessScreen` from inside a
  church.
- **Logout** (Settings, Account section) — always shown. Fully signs out of
  Firebase Auth and returns to `AuthChoiceScreen` (`pushAndRemoveUntil`,
  same as account deletion in Settings) — not straight to `SignInScreen`,
  since someone logging out may equally want to sign into a different
  account (Sign Up) as sign back into this one.

### Signup email verification

1. Once `CompleteProfileScreen` writes `users/{uid}` (with `emailVerified:
   false`), `AppEntry` routes to `EmailOtpVerificationScreen` instead of
   continuing to church resolution.
2. The screen calls the callable `requestSignupEmailVerificationCode` on
   mount — callable, not `onRequest` like password reset, because the
   caller is already signed in at this point; `request.auth.uid` (not a
   client-supplied email) decides whose account gets the code and whose
   `users/{uid}` doc is later updated.
3. The server looks up the caller's own Firebase Auth email, generates a
   six-digit code and stores only a keyed hash in
   `emailVerificationChallenges/{opaqueHmacId}` (`opaqueHmacId` is an
   HMAC of the uid — a separate collection and keying scheme from
   `passwordResetChallenges`, which is keyed by email and reachable pre-auth).
   Same limits as password reset: 10-minute lifetime, 60-second resend
   cooldown, five requests/hour, five verify attempts.
4. Submitting the code calls `verifySignupEmailVerificationCode`; on match
   it sets `users/{uid}.emailVerified: true` in the same transaction that
   marks the challenge verified. There is no separate token/hand-off step
   like password reset's `resetToken` — verifying *is* completing, since
   nothing further needs to happen with elevated trust afterward.
5. `AppEntry` is already watching the identity stream, so it moves past
   this screen on its own once `emailVerified` flips true — the screen
   itself never navigates on success.
6. The back button signs out and returns to `AuthChoiceScreen`
   (`pushAndRemoveUntil`) rather than popping — this screen is rendered
   inline by `AppEntry`, never pushed, so there is no previous route to pop
   to; the account and identity doc are left exactly as they are (still
   unverified), and signing back in with the same credentials returns here.

**`requestSignupEmailVerificationCode`/`verifySignupEmailVerificationCode`
must be deployed** (`firebase deploy --only functions:requestSignupEmailVerificationCode,functions:verifySignupEmailVerificationCode`,
or a full functions deploy) before this screen can send or verify a code —
until then, the initial send on mount fails, no email arrives, and the
resend countdown never starts (it only starts after a successful send), so
"Resend code in 60s" appears stuck. This is a deployment gap, not a code
defect.

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
  `auth_navigation.dart` (`goToSignIn`/`goToSignUp` — the only way any
  screen switches between Sign In and Sign Up; see "Switching between Sign
  In and Sign Up" below), `auth_choice_screen.dart` (`AuthChoiceScreen`,
  first screen for anyone signed out), `sign_in_screen.dart` (`SignInScreen`,
  dedicated sign-in),
  `complete_profile_screen.dart` (signup step + `ProfileDraft`, see "Signup
  and entry gate" above for its two call shapes),
  `create_account_screen.dart` (`CreateAccountScreen`, email/password +
  identity write, the last step of sign-up),
  `email_otp_verification_screen.dart` (signup email-OTP gate),
  `create_auth_account_screen.dart` (`CreateAuthAccountScreen`, now
  admin-create-member only — see below),
  `request_church_access_screen.dart` (self-service request access),
  `request_pending_screen.dart` (pending state + approval-notification opt-in),
  `login_request_screen.dart` (admin-create path, `adminCreateMode: true`),
  `login_entry_screen.dart`, `forgot_password_screen.dart`,
  `password_reset_code_screen.dart`, `reset_password_screen.dart`.
  `screens/select-church-screen.dart` — `SelectChurchScreen` (two-tab
  shell, always root-level; the entry-gate screen for both "no approved
  membership anywhere" and "first-ever approval", and also reachable —
  clearing the stack — from Settings > Register for another church) and
  `ChurchPickerScreen` ("Welcome Home", Your churches / Other churches —
  `SelectChurchScreen`'s "Churches" tab body, no `Scaffold`/`AppBar` of its
  own, never pushed).
  `screens/community/global_feed_full_screen_viewer.dart` (all-churches
  swipeable feed, reached by tapping a post in `GlobalFeedListView`).
- Shared widgets: `widgets/global_feed_list_view.dart` (inline cross-church
  feed, `SelectChurchScreen`'s Home tab body); `widgets/app_bottom_tab_bar.dart`
  (`AppBottomTabBar`/`AppBottomTabItem` — shared by `ChurchTabScreen` and
  `SelectChurchScreen`); `widgets/church_quick_switcher_sheet.dart`
  (approved-memberships-only switcher, opened from
  `screens/church_tab_screen.dart`'s app bar).
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
  `completePasswordReset`, `sendPasswordResetSmtpEmail`,
  `requestSignupEmailVerificationCode`/`verifySignupEmailVerificationCode`
  (callables, `emailVerificationChallenges` collection), and
  `notifyMemberOnApproval` (approval push+email, opt-in only).
- Local onboarding state: SharedPreferences `onboarding_completed`.

## Invariants and failure behaviour

- Never generate or verify reset/verification codes on the client.
- Never log codes, reset tokens, passwords or SMTP secrets.
- `emailVerified` is only ever set to `false` by
  `UserIdentityRepository.createIdentity` (client-side, at identity-doc
  creation) and only ever flipped to `true` by
  `verifySignupEmailVerificationCode` (server-side, inside the same
  transaction as the code check) — no other path writes it either way, so a
  doc's `emailVerified` state always traces back to one of those two.
- `emailVerified` is enforced in `firestore.rules`, not just by `AppEntry`'s
  routing — `hasVerifiedEmail()` gates `isApprovedMember`/`isChurchAdmin`/
  `isSuperAdmin` and every plain-signed-in content read/write (church
  public content, `globalFeeds`, `globalPrayerRequests`, `globalFeedback`,
  the `members/{docId}` self-create branch, etc.), so an unverified
  account can't reach real data through a direct API/SDK call even if it
  bypassed the app's own screens. The one deliberate exception is
  `users/{uid}` itself (`isSelf`, unchanged) — that rule has to stay
  reachable regardless of `emailVerified`, or the app could never read its
  own flag to know when to stop showing the OTP screen.
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
| AUTH-01 | Fresh install | Onboarding appears once; completion persists after relaunch; `AuthChoiceScreen` (Sign In / Sign Up) follows, not a guessed step. |
| AUTH-01a | Tap "Sign Up" | `CompleteProfileScreen` opens first — no email/password asked yet, and no Firebase account exists at this point. |
| AUTH-01e | On `CompleteProfileScreen` (sign-up shape), press system/app-bar back | Returns to `AuthChoiceScreen` (no "Login" link on this screen — the back button is the only way across); entered fields are discarded. |
| AUTH-01f | Toggle back and forth several times between `SignInScreen` and `CompleteProfileScreen` (back button, then "Sign Up" again, repeat) | The nav stack never grows past `AuthChoiceScreen` + the current screen — back from either screen always returns straight to `AuthChoiceScreen`, never through a chain of previously-visited screens. |
| AUTH-01b | Complete the profile step, then continue | `CreateAccountScreen` opens (email + password + confirm); submitting there — not the profile step — is what creates the Firebase account. |
| AUTH-01c | On `CreateAccountScreen`, use an email that already has an account (`email-already-in-use`) | An explanatory message shows and `SignInScreen` opens pre-filled with that email; the collected profile draft is discarded (no account was created to attach it to). |
| AUTH-01d | Tap "Sign In", then use an email with no account (`user-not-found`) | An explanatory message shows; there is no "Register" link on this screen — the app-bar back button (to `AuthChoiceScreen`, then "Sign Up") is the way into the sign-up path. |
| AUTH-02 | Valid login for approved member | Correct selected church opens without an unmounted-provider lifecycle error. |
| AUTH-03 | Wrong password/disabled user | Localized error; no membership data shown. |
| AUTH-04 | Complete a full sign-up (`CompleteProfileScreen` → `CreateAccountScreen`) | Phone field on the profile step shows a fixed "+91" prefix and only accepts 10 digits; submitting the account step creates the Firebase account and writes `users/{uid}` (draft fields + email, `emailVerified: false`) in one step, then proceeds to email-OTP verification, not straight to church resolution. |
| AUTH-04d | Reach `AppEntry` with a Firebase account but no `users/{uid}` doc (resume case — e.g. an interrupted sign-up on an older build) | `CompleteProfileScreen` opens in its resume shape (no `onContinue`) and writes the identity doc directly using the already-signed-in user. |
| AUTH-04a | Reach `EmailOtpVerificationScreen` for the first time | A code is requested automatically on mount (no prior screen triggers it); resend is disabled for 60s. Requires `requestSignupEmailVerificationCode` to be deployed — if it isn't, the send fails, no email arrives, and "Resend" stays stuck at 60s (deployment gap, not a UI bug). |
| AUTH-04f | On `EmailOtpVerificationScreen`, tap the back button | Signs out and returns to `AuthChoiceScreen`; the identity doc is untouched (still unverified) — signing back in with the same credentials lands back on this screen. |
| AUTH-04g | With an unverified account's ID token, call Firestore directly (bypassing the app's screens) for church-public content, `globalFeeds`, or a `members/{docId}` self-create | Denied by `firestore.rules` (`hasVerifiedEmail()`) — the security boundary matches the UI gate, not just the routing. |
| AUTH-04b | Enter the correct code | `users/{uid}.emailVerified` flips to true server-side; `AppEntry` moves on by itself (screen never navigates directly). |
| AUTH-04c | Enter the wrong code repeatedly / an expired code / resend before cooldown ends | Same behaviour as password-reset codes (attempts decrement, fifth failure blocks, expired code rejected, early resend disabled) — separate challenge collection/limits, same rules. |
| AUTH-04e | Sign in with an account whose identity doc predates the `emailVerified` field, or one an admin action seeded directly (e.g. `attachFirebaseAuthToMember`) | No OTP screen — `emailVerified` reads as true (missing field, not false) and `AppEntry` goes straight to church resolution. |
| AUTH-05 | Signed in, identity but no approved membership anywhere | `SelectChurchScreen` opens directly (no separate guest hub), feed-first; church content is inaccessible. |
| AUTH-06 | Pending membership | Shows under "Your churches"; tapping it shows a "still pending" message instead of entering. |
| AUTH-07 | Approved in one church, pending in another | `ChurchPickerScreen`'s "Your churches" shows both (pending one blocked by the message above); approved-anywhere still auto-enters on next cold start. |
| AUTH-07a | First-ever approval, fresh install/new device (nothing resolvable yet) | `SelectChurchScreen` opens instead of guessing; the "Churches" tab shows `ChurchPickerScreen`; picking an approved church enters it and every later launch resumes it directly, no picker. |
| AUTH-07b | Approved in two churches, first-ever entry | Picker shows both under "Your churches"; picking either works and becomes the remembered church. |
| AUTH-08 | Request access as an existing identity | No name/phone/dob/etc. fields shown; one tap submits; lands on `RequestPendingScreen`; church admin sees a normal pending request. |
| AUTH-08a | Request access to a church you don't administer (the common case) | Submission succeeds and lands on `RequestPendingScreen` even though the founding-admin auto-approve check (`churches/{cid}/members` + `config/app` reads) is denied for you by rules — that failure is caught and treated as "not auto-approved," not a submission error. |
| AUTH-08b | Approved member reads church-visible data gated by `isApprovedMember` (`config/app`, `families`, `groups`, `feeds` create, `prayer_requests`, `learning_results`, etc.) | Succeeds — `isApprovedMember` now checks `churches/{cid}/members/{uid}`, the actual post-migration collection (was silently checking the retired `.../users/{uid}` path, so every approved member failed this check for anything gated by it alone, not just admins/super admins). |
| AUTH-08c | Request access, land on `RequestPendingScreen` (still pending), then background/foreground the app or navigate around while pending | No repeated `PERMISSION_DENIED` church-data reads — `currentChurchIdProvider` (which `appConfigProvider`/`textContentProvider`, hence every `context.t()`/`ref.t()`, depends on) no longer falls back to trusting a locally-cached church id without checking it's still an approved membership; a stale/foreign local church reference (e.g. left over from a different account's session on the same device) now resolves to no church rather than one the signed-in user was never approved for. |
| AUTH-09 | Request access twice (double tap, or a second device mid-request) | Second attempt does not overwrite the first row or reset an approved membership back to pending; also lands on `RequestPendingScreen`. |
| AUTH-09a | Tap "Notify me when approved" on the pending screen | OS notification permission is requested if not already granted; `notifyOnApproval: true` is set; admin then approves | Push and a queued email both arrive; a second approval-triggering write (e.g. editing category) does not resend. |
| AUTH-09b | Reach a church with an existing pending row again (Other Churches, or Your Churches in `ChurchPickerScreen`) | `RequestPendingScreen` opens directly (no duplicate row created) reflecting the existing `notifyOnApproval` state. |
| AUTH-09c | Request access without tapping "Notify me" | No push or email is sent when later approved. |
| AUTH-10 | Browse churches list | Already-requested/joined churches do not appear with a "Request access" button. |
| AUTH-11 | Tap the church name in `ChurchTabScreen`'s app bar, with 2+ approved churches | `ChurchQuickSwitcherSheet` opens listing only approved memberships (no Other Churches, no feed); the active church shows a check mark and is not tappable. |
| AUTH-11a | Same, with exactly one approved church | Sheet still opens, showing that one church (checked, not tappable) — there's nothing else to switch to, but it's not hidden. |
| AUTH-12 | Pick a different approved church from the sheet | Session is not ended; whole nav stack is replaced (`pushAndRemoveUntil`) so the church left behind is not reachable via back. |
| AUTH-12a | Press system back while inside a church (any tab) | Nothing happens — `PopScope(canPop: false)` blocks it; only the app-bar church name (switch) or Settings > Register-another-church/Logout can leave. |
| AUTH-12b | Settings > "Register for another church" | Opens `SelectChurchScreen` (Home tab first) with the whole stack cleared (`pushAndRemoveUntil`) — no back button, matching its entry-gate behaviour; the "Churches" tab, where requesting access behaves exactly like the entry-gate flow. |
| AUTH-12c | Tap a post in `SelectChurchScreen`'s Home tab feed | Opens `GlobalFeedFullScreenViewer` at that post — vertical swipe between global posts only, no segment toggle, no create-post action; back returns to `SelectChurchScreen`. |
| AUTH-12d | Tap the "Churches" tab on `SelectChurchScreen` | Shows `ChurchPickerScreen` (Your Churches / Pending Approval / Other Churches) in place — no push, no back button involved; tapping "Home" switches back to the feed the same way, and the app bar title stays "Church Tree" on both tabs. |
| AUTH-13 | Logout | Firebase session actually ends; lands on `AuthChoiceScreen` (Sign In / Sign Up), not straight to `SignInScreen`; relaunch requires signing in again. |
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
