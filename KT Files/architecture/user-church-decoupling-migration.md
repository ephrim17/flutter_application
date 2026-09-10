# User / Church Decoupling — Implementation Plan

Status: **ready for implementation**. No code written yet.
Authored: 2026-09-08.

## How to use this document

This is a handover spec. Every decision below is settled — do not re-open them
without asking. Section 9 ("Critical correctness notes") contains the things
that cause security bugs or data loss if implemented naively; read it before
writing code.

All file references were verified against the working tree on 2026-09-08. Line
numbers may drift as you edit — the symbol names are authoritative.

Repo rules that still apply: `AGENTS.md` (localization, church scoping,
`mounted`/`ref` safety), `CLAUDE.md` (release verification, docs policy).

---

## 1. Decisions

| # | Decision | Chosen |
|---|---|---|
| D1 | Membership collection | **Rename** `churches/{cid}/users` → `churches/{cid}/members` |
| D2 | Church-less experience | **Guest shell** — personal, non-church features while unaffiliated |
| D3 | Migration style | **One-shot cutover** on a branch against a copy database (revised — see §3) |
| D4 | Day streak | **Global** — one streak per person, not per membership |
| D5 | Signup captures | **Essentials** (name, phone, dob, gender); rest after approval |
| D6 | Church-specific fields | **Asked at request access** (category, family, groups) |
| D7 | Guest learning | **Global modules only**; church modules stay behind approval |
| D8 | `phone` + `contact` | **Merged** into a single `phone` field |
| D9 | Learning tracks | **Fully separated** — Church Tree modules are personal; church modules are the church's (§5.6) |

### What "decoupling" means

The user *record* becomes independent of any church. A person survives church
deletion, leaving and rejection — profile, favorites, reading plans, learning
progress and streak persist and follow them into every church they join.

The user *experience* stays gated: church content (Home, For You, feeds,
announcements, events, prayer, dashboard, Studio) requires an approved
membership. Unaffiliated users get the **guest shell** (§5.3) — personal
features only.

---

## 2. Why this is necessary

Five problems, all verified in the current code.

**2.1 — There is nowhere to put a person.** `appUserProvider`
(`providers/user_provider.dart:53`) yields `null` when `currentChurchIdProvider`
has no id, and `AppEntry` (`screens/entry/app_entry.dart:172`) maps
`user == null` to `SelectChurchScreen`. Identity cannot be written or read
before a church is chosen — which is exactly what D5 requires. **This is a hard
blocker, not a preference.**

**2.2 — Profile details are re-typed per church.**
`create_auth_account_screen.dart` collects only email and password (`:51–53`).
Everything about the person lives in the 2-step request form
(`login_request_screen.dart:57–84`), filled again for every church joined.

**2.3 — Church lifetime controls user lifetime.**
`AuthRepository._deleteFirestoreUserData` (`firestore_authentication.dart:251`)
and `MembersRepository._deleteChurchUserData` (`members_repository.dart:367`)
delete profile, reading plans and group rows when a *membership* ends.
`firestore.rules` lets a super admin delete a church doc, which **orphans
rather than deletes** every subcollection beneath it.

**2.4 — Profile edits don't propagate.** `ChurchUsersRepository.updateProfile`
(`church_user_repository.dart:26`) writes the current church only, then
best-effort fans the *photo* to that church's feeds (`:127`) and groups (`:164`).
Name changes propagate nowhere.

**2.5 — It doesn't scale.** `userChurchesProvider`
(`select-church-screen.dart:41`) does **one read per enabled church, per user,
per visit** to the picker.

**2.6 — Live bug: stale FCM tokens.** `authToken` is a *device* property stored
on the *membership* doc, refreshed only for the selected church
(`notification_service.dart:213`). Fan-out reads it at `functions/src/index.ts:708`
and `:770`. A user in churches A and B who last opened A has a dead token in B,
so B's notifications silently fail. Fixed as a side effect (Phase 5).

---

## 3. Environment and branching (D3 — revised)

The owner has:

- A **`migrationv1` Firestore database** — a copy of production.
- **10+ churches** in production.
- **No live end users yet.**

This changes the migration strategy. An earlier draft specified dual-write with
a compatibility shim; that exists to keep a *live* app working while data
changes shape underneath it. With a copy database, a feature branch, and no live
users, it is unnecessary complexity.

**Do this instead:**

1. Branch from `main` (e.g. `feat/user-church-decoupling`). All app changes live here.
2. Point the branch build at the `migrationv1` database.
3. Write the new code directly against the new schema — **no dual-write, no `AppUser` compatibility shim.**
4. Run the backfill against `migrationv1`. Iterate until clean.
5. Test the full app against migrated data.
6. Cutover: run the backfill on production, deploy rules + indexes + functions, merge the branch.

This removes an entire phase, the three-target write fan-out, and the
old/new divergence hazard.

### Multi-database setup required

`firebase.json` currently declares a single default-database Firestore config:

```json
"firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" }
```

To target `migrationv1` you must:

- Convert `firestore` to an array with a `database` key per entry, so rules and indexes deploy to the named database.
- Select the database in the Flutter app with `FirebaseFirestore.instanceFor(app: ..., databaseId: 'migrationv1')`, driven by a build-time constant.

  **Gotcha — there is no single injection point today.** `firestoreProvider` is
  declared **three times**, and eight files call `FirebaseFirestore.instance`
  directly:

  ```
  providers/select_church_provider.dart:8            final firestoreProvider
  providers/authentication/firebaseAuth_provider.dart:11  final firestoreProvider
  services/firestore/firestore_provider.dart:4       final firestoreProvider

  direct FirebaseFirestore.instance callers:
    https_service/https_service_class.dart
    providers/user_provider.dart
    providers/feeds_provider.dart
    providers/onboarding_provider.dart
    providers/select_church_provider.dart
    providers/authentication/firebaseAuth_provider.dart
    screens/side_drawer/financial_dashboard_screen.dart
    services/firestore/firestore_provider.dart
  ```

  **Collapse these to one provider before anything else.** If any path keeps
  using `FirebaseFirestore.instance`, part of the app will silently read and
  write **production** while the rest uses `migrationv1` — corrupting live data
  with no error. Do this first, verify it, then proceed.
- Cloud Functions v2 triggers default to `(default)`. Pass the `database` option on every Firestore trigger you want firing against `migrationv1`.

**Gotcha — the installed `firebase-tools` (15.11.0) silently no-ops on this
array config.** `firebase deploy --only firestore:rules,firestore:indexes`
against the array form prints `Deploy complete!` but skips every actual step
(no "compiled successfully", no "released rules", no indexes build) — and a
rules+indexes deploy targeting only `firestore:indexes` throws
`TypeError: Cannot read properties of undefined (reading 'map')` in
`deploy.js`. Confirmed by testing: `migrationv1` had zero rules deployed and
every read/write failed `PERMISSION_DENIED` until worked around. Likely fixed
in a newer `firebase-tools` (15.29.0 was available at the time), but `npx
firebase-tools@latest` failed here on an unrelated local npm cache
permissions error — untested whether upgrading actually fixes it.

**Workaround that does work today:** temporarily replace the array with a
single object carrying an explicit `database` key —
`{ "database": "migrationv1", "rules": ..., "indexes": ... }` — deploy, then
switch back to the array for the committed config. Single-object + explicit
`database` deploys correctly (verified: rules compiled, uploaded, released;
indexes explicitly confirmed "for migrationv1 database"). Do this once per
database you need to update until the tooling is confirmed fixed.

Verify writes land in the intended database before running anything
destructive.

---

## 4. Current state audit

### 4.1 Field ownership

Every field on `AppUser` (`models/app_user_model.dart`):

| Concern | Fields | Today | Target |
|---|---|---|---|
| **Identity** | `name`, `email`, `phone` (absorbs `contact`, D8), `profilePhotoUrl`, `dob`, `gender`, `location`, `address`, `maritalStatus`, `weddingDay`, `educationalQualification`, `talentsAndGifts` | church user doc | `users/{uid}` |
| **Membership** | `approved`, `role`, `category`, `familyId`, `churchGroupIds`, `membershipCurrentStatus`, `membershipNotes`, `additionalNotes`, `createdAt` | church user doc | `churches/{cid}/members/{uid}` |
| **Church-attested** | `solemnizedBaptism`, `baptismDate`, `baptismCertificateNumber`, `baptismChurchName`, `baptismPastorName`, `marriageSolemnizationChurchType`, `marriageSolemnizationChurchName` | church user doc | membership |
| **Church-private** | `financialStabilityRating`, `financialSupportRequired` | church user doc | membership, **not member-readable** |
| **Device** | `authToken` | church user doc | `users/{uid}/devices/{installationId}` |
| **Engagement** | `dayStreak`, `lastStreakRecordedAt` | church user doc | `users/{uid}` |

### 4.2 Misfiled user-owned data

| Data | Today | Problem |
|---|---|---|
| Reading plans | `churches/{cid}/users/{uid}/readingPlans` | Duplicated per church; deleted with membership |
| Learning progress | `churches/{cid}/users/{uid}/learning_progress` | Same |
| Bible favorites | `SharedPreferences` `all_highlights` (`favorites_provider.dart:17`) | Device-local; lost on reinstall |
| Avatar blob | Storage `churches/{cid}/users/{uid}/profile/…` (`church_user_repository.dart:52`) | Church-scoped storage for a personal asset |
| Onboarding flag | `SharedPreferences` `onboarding_completed` | Device-local — **leave as is** |

### 4.3 The already-existing hook

`users/{uid}` exists in `FirestorePaths` (`userDoc`, `usersCollection`,
`userReadingPlans`) and in `firestore.rules`, commented *"Vestigial global
profile doc — owner-only until/unless this becomes the real cross-church
identity record."* Nothing writes it; it is read once, during account deletion
(`firestore_authentication.dart:267`). This migration is the "unless".

---

## 5. Target design

### 5.1 Data model

```text
users/{uid}                                   ← canonical person
  name, phone, dob, gender,                   ← captured at signup (D5)
  email, profilePhotoUrl, location, address,
  maritalStatus, weddingDay,
  educationalQualification, talentsAndGifts,  ← completed after approval
  dayStreak, lastStreakRecordedAt,            ← global (D4)
  lastActiveChurchId, profileComplete,
  schemaVersion, createdAt, updatedAt
  /devices/{installationId}   fcmToken, platform, topics, updatedAt
  /readingPlans/{planId}
  /learning_progress/{docId}  ← CHURCH TREE (global) modules only — see §5.6
  /favorites/{verseKey}

churches/{cid}/members/{uid}                  ← membership only (RENAMED)
  uid,                                        ← REQUIRED for the group query
  approved, role,
  category, familyId, churchGroupIds,         ← captured at request access (D6)
  membershipCurrentStatus, membershipNotes, additionalNotes,
  baptism*, marriageSolemnization*,           ← admin-only
  financialStabilityRating, financialSupportRequired,
  linkedUid | null,                           ← null = admin-created, no auth
  joinedAt, schemaVersion,
  displayName, displayEmail, displayPhone, displayPhotoUrl,
  displayDob, displayGender, identitySyncedAt
  /learning_progress/{docId}  ← CHURCH modules only — see §5.6
```

Storage moves `churches/{cid}/users/{uid}/profile/…` → `users/{uid}/profile/…`.

Also rename `churches/{cid}/groups/{gid}/users` → `…/groupMembers`, keyed by
uid. This removes the collection-group name collision permanently (§5.2) and
fixes email-keyed rows (§9.4).

### 5.2 Membership discovery

The rename makes `members` unambiguous, so discovery is one query:

```dart
firestore.collectionGroup('members').where('uid', isEqualTo: currentUid)
```

- **Rule:** `match /{path=**}/members/{memberId} { allow read: if resource.data.uid == request.auth.uid; }`
- **Index:** collection-group index on `members.uid` in `firestore.indexes.json`.
- Requires `uid` stored **on the document**, not only as the doc id. It already is (`firestore_authentication.dart:330`).

No mirror collection, no `churchIds` array — there is nothing to keep in sync.

Under the old name this was impossible: `users` is also the collection under
`churches/{cid}/groups/{gid}/users`, so the query would have matched group rows.

### 5.3 Guest shell

Shown whenever a signed-in user has **no approved membership**. That covers four
situations — do not tie it to "pending" alone:

1. Signed up, hasn't requested any church.
2. Request pending.
3. Request declined (a decline deletes the membership; there is no rejected state).
4. Removed from, or left, their only church.

**Tabs:** Bible | Learning | My Churches

| Tab | Contents | Sources |
|---|---|---|
| Bible | Reader, favorites, reading plans | Bundled/downloaded Bible, `users/{uid}/favorites`, `users/{uid}/readingPlans` |
| Learning | **Global** published modules + personal progress (D7) | `learning_modules` via `watchPublishedModules()`, `users/{uid}/learning_progress` |
| My Churches | Pending status, browse churches, request access | `collectionGroup('members')`, `churches` (public read) |

A pending user can request additional churches from the third tab, so multiple
pending requests may exist at once. Approval into any one of them wins.

**Excluded:** Home, For You, feeds, announcements, events, prayer, dashboard,
Studio, church-specific learning modules, and **daily verse** (§9.6).

**No new security rules are needed.** Everything the guest shell reads is
either the user's own data (`users/{uid}`) or already public: `learning_modules`
is `allow read: if isSignedIn()`, `bible_versions` is `allow read: if true`.
Guest access is a UI-shell decision, not an authorization one. There is no
"guest" role — these users are fully authenticated.

**Naming:** do not use "guest" in provider, model or rule identifiers. It
conventionally implies *unauthenticated* and will mislead someone into writing a
rule that omits `request.auth`. Name the state `noActiveMembership` or similar.
"Guest" is acceptable in user-facing copy only.

### 5.4 Entry state machine

```text
App start
  -> onboarding incomplete        : onboarding                  (unchanged)
  -> signed out                   : auth — email + password     (unchanged)
  -> signed in, no identity doc   : complete profile            ← NEW
  -> super admin                  : mode chooser                (unchanged)
  -> signed in, no approved membership : GUEST SHELL            ← NEW
  -> approved                     : ChurchTabScreen             (unchanged)
```

`AppEntry`'s gate changes from "no church user doc → church list" to "no
identity doc → profile step; identity but no approved membership → guest shell".

**Approval transition:** when a membership flips to approved, show a
**full-screen loader**, then the church shell. The loader must cover the church
theme repaint (`appConfigProvider` → new colors) and the section-config fetch,
which is where the UI would otherwise flash. All user state carries over
untouched — it lives on `users/{uid}` and never moved.

### 5.5 Form split

Today's 2-step member form (`login_request_screen.dart`) splits three ways:

| Step | Fields | Writes to |
|---|---|---|
| **Signup** (new, once ever) | `name`, `phone`, `dob`, `gender` | `users/{uid}` |
| **Request access** (per church, short) | `category`, `familyId` / family name, `churchGroupIds` | `churches/{cid}/members/{uid}` |
| **Profile, after approval** | `location`, `address`, `maritalStatus`, `weddingDay`, `educationalQualification`, `talentsAndGifts`, `profilePhotoUrl` | `users/{uid}` |

Joining a **second** church asks only the short middle step.

The profile step is its **own screen** after account creation — not another page
inside `create_auth_account_screen` — so an abandoned signup can resume.

Post-approval completion uses a **non-blocking prompt sheet**, reusing
`widgets/prompts/prompt_sheet.dart` sequenced by `prompt_sequence_provider`,
driven by `profileComplete`. It must never gate access — the member is already
approved.

The **4-step admin form** (`_showAdminSections`, `login_request_screen.dart:91`)
keeps its current shape. An admin-created member has no identity doc, so the
admin supplies everything (§9.3).

### 5.6 Two learning tracks (D9)

Learning splits into two tracks that never mix.

| | **Church Tree modules** | **Church modules** |
|---|---|---|
| Source | global `learning_modules` | `churches/{cid}/learning_modules` |
| Who authors | super admin | church (see §7 follow-up) |
| Visible | guest shell **and** inside any church | inside that church only |
| Progress | `users/{uid}/learning_progress` | `churches/{cid}/members/{uid}/learning_progress` |
| Results | none — attempts live in progress | `churches/{cid}/learning_results` |
| Survives leaving a church | yes | progress no; the church's `learning_results` rows survive |

Church Tree progress follows the person everywhere. Church learning is the
church's curriculum and its record.

**This is a behaviour change, not just a move.** Today the tracks are merged:
`submitSectionQuiz` (`learning_module_repository.dart:338`) and
`submitModuleExam` (`:423`) both write to `churchLearningResults`
**unconditionally**, and neither records whether the module came from the global
or the church collection. Completing a Church Tree module inside a church
currently files a result into that church's records, and its progress is stored
per-church — so the same global module restarts from zero in the next church.

**Required changes:**

1. Record the module's source. Either a `source: 'global' | 'church'` field on `LearningModule`, or resolve it at submit time by which collection the module id came from. A field is safer — the submit path shouldn't guess.
2. Branch both submit methods on that source: global → write progress to `users/{uid}/learning_progress` and **no** results row; church → keep today's behaviour under the membership.
3. `learning_results` rules are unchanged (`allow create: if isApprovedMember(churchId)`) and stay correct, because guests never write there.
4. Guest writes to `users/{uid}/learning_progress` are covered by the existing self-write rule — no new rules needed.

### 5.7 Streak (D4)

One streak per person on `users/{uid}`, counting any day the app is opened —
including in the guest shell.

- `ChurchUsersRepository.updateDailyStreak` (`church_user_repository.dart:196`) moves onto the identity doc; transaction body otherwise unchanged.
- `AppBootstrap._syncDailyStreakIfNeeded` (`app_bootstrap.dart:40`) currently early-returns when `churchId == null` — key it on uid alone.
- Backfill collapses per-church streaks to the **maximum**, keeping the latest `lastStreakRecordedAt`.
- `_WelcomeCard` (`home_screen.dart:243`) reads the streak from identity.

---

## 6. Phases

### Phase 0 — Setup

- Confirm `migrationv1` is a current copy of production.
- **Collapse the three duplicate `firestoreProvider` declarations and the eight direct `FirebaseFirestore.instance` callers into one provider (§3).** This is the highest-risk step in the whole plan — a missed caller writes to production while everything else uses `migrationv1`.
- Wire the database selector into that single provider behind a build-time constant.
- Create the branch. Verify a write from the branch build lands in `migrationv1`, not production — check the console, don't assume.
- Build the migration harness at `functions/scripts/migrate/` (Node + TS, reusing the existing functions toolchain): `--dry-run` default, `--database` target, `--church=<id>` scoping, JSON run report, conflicts CSV.

**Exit:** dry-run reports all churches and member counts; zero writes.

### Phase 1 — Models, paths, rules

- `models/user_identity_model.dart` (`UserIdentity`) and `models/church_membership_model.dart` (`ChurchMembership`). **Delete `AppUser`** — no shim, per §3.
- `firestore_paths.dart`: `churchMembers`, `churchMemberDoc`, `userDevices`, `userFavorites`, `userLearningProgress`. Remove `churchUsers`/`churchUserDoc`.
- `firestore.rules`: `members` block, collection-group read rule (§5.2), `users/{uid}` self-write with field validation, and a **client-denied `display*` guard**.
- `firestore.indexes.json`: collection-group index on `members.uid`.

**Exit:** `flutter analyze lib/church_app test` clean; rules unit tests pass.

### Phase 2 — Backfill script

One pass performs the split **and** both renames.

- **Key resolution.** If the member doc id is a real Auth uid (verify via `admin.auth().getUser`), it becomes the identity key and `linkedUid` is set. Otherwise (admin-created, no auth — §9.3) write **no** identity doc; carry the row to `members/{sameId}` with `linkedUid: null`, profile living in `display*` as authoritative.
- **Conflict resolution.** One person across several churches yields several candidate profiles. Newest `updatedAt` wins per field; non-empty beats empty; every discarded value goes to the conflicts CSV.
- **Normalisation.** `dayStreak` → `int` (§9.5). Emails lowercased. Streaks collapsed to max. `phone` absorbs `contact` where `phone` is empty (D8).
- Derive `profileComplete` from the post-approval field set (§5.5).
- Populate `uid`, `joinedAt`, `display*` on every membership.
- Move `readingPlans` to `users/{uid}/readingPlans`.
- **Split `learning_progress` by module source (§5.6).** Existing
  `churches/{cid}/users/{uid}/learning_progress` docs mix both tracks in single
  `progress` documents — `completedSectionIds`, `completedModuleIds`, `attempts`
  and the attempt-count maps all commingle global and church module ids. For
  each entry, look the module id up in global `learning_modules` versus
  `churches/{cid}/learning_modules`:
  - global → merge into `users/{uid}/learning_progress` (union across churches; a person may have completed the same Church Tree module in two churches — keep the best attempt and the union of completed ids)
  - church → keep under `churches/{cid}/members/{uid}/learning_progress`
  - module id resolving to neither (deleted module) → drop, and log to the run report
- **Tag existing `learning_results` rows** with `source: 'global' | 'church'` by the same lookup, so admin dashboards can filter historical rows. Do not delete them — they are the church's record.
- Re-key `groups/{gid}/users` → `groups/{gid}/groupMembers`, keyed by uid.

**Exit:** re-run until the dry-run diff is empty; `count(users) == count(distinct linked uids)`; conflicts CSV reviewed.

### Phase 3 — App rewrite

- `userIdentityProvider` (auth-scoped, **no** churchId dependency) and `currentMembershipProvider` (church-scoped) replace `appUserProvider`.
- `AppEntry` gate per §5.4; new profile step; guest shell per §5.3.
- `login_request_screen.dart` member mode shrinks to the church-specific step; admin mode unchanged.
- Profile screen gains post-approval fields and the completion prompt.
- `userChurchesProvider` → `collectionGroup('members')`.
- Delete `updateProfile`'s manual photo fan-out (replaced in Phase 6).
- Backend triggers move to `churches/{cid}/members/{uid}`: `rebuildChurchDashboardMemberMetrics` (`index.ts:1091`), `ensureFinanceGroupMember` (`financial.ts:375`).

**Exit:** CHURCH-01…CHURCH-12 pass against migrated data, plus §11 cases.

### Phase 4 — User-owned data

- Reading plans read from `users/{uid}/readingPlans`.
- **Implement the learning split (§5.6):** add the module `source` discriminator, branch `submitSectionQuiz` (`learning_module_repository.dart:338`) and `submitModuleExam` (`:423`) on it, and point global-module progress at `users/{uid}/learning_progress` with no results row. Church modules keep today's behaviour under the membership.
- Favorites: `SharedPreferences` → `users/{uid}/favorites`, merging the local set on first sync so nobody loses highlights. Keep local storage as the offline cache.
- Avatars → `users/{uid}/profile/…`; add the `storage.rules` block, copy blobs, rewrite `profilePhotoUrl`.

### Phase 5 — Devices and FCM

- `users/{uid}/devices/{installationId}`: `fcmToken`, platform, topics, `updatedAt`. Written every launch and on `onTokenRefresh`, regardless of selected church.
- `sendFeedPostNotification` (`index.ts:701`) and `sendPrayerRequestAdminNotification` (`index.ts:746`) resolve tokens via church member uids → device docs, not `authToken`.
- Topic subscriptions unchanged.

**Exit:** two churches, one device — post in the *non-selected* church, confirm delivery. Fails today (§2.6).

### Phase 6 — Identity fan-out

One `onDocumentWritten('users/{uid}')` function replaces all client-side denormalisation:

- Refresh `display*` on every membership from `collectionGroup('members').where('uid','==',uid)`, **skipping unlinked rows** (§9.2).
- Update `userName`/`userPhoto` on that user's `feeds`, `globalFeeds`, `groupMembers`, `faith_engagement`, `learning_results`.
- Batched, idempotent, short-circuited when no denormalised field changed.

**Exit:** rename in Profile → older feed posts update within seconds.

### Phase 7 — Lifecycle

- **Leave church:** delete membership + group rows only. Identity, favorites, plans, progress, streak survive.
- **Delete church (super admin):** callable function recursively deleting the church subtree. Users survive.
- **Delete account:** delete `users/{uid}`, all memberships, devices, Storage blobs, then the Auth user. Closes the *no account-deletion UI* blocker in `testing/android-release-readiness-2026-08-13.md`.

### Phase 8 — Production cutover

- Fresh export of production.
- Run the backfill on production.
- Deploy rules, indexes and functions.
- Merge the branch; flip the database constant back to `(default)`.
- Verify: sign in, church list, request access, approval, notifications.

---

## 7. Out of scope (follow-ups)

- **Church-admin-authored learning modules.** Today creation is super-admin only — every write in `learning_module_repository.dart` calls `_requireSuperAdmin()` (`:38–305`), reachable only from `super_admin_home_screen.dart:597`. Note that `firestore.rules` *already* allows `isChurchStaff` to write `churches/{cid}/learning_modules`, so this is largely a client-side unlock plus Studio UI. Track separately.
- Manual "link to existing account" action in the members screen (§9.3, email-mismatch recovery).
- Global default daily verse, which would let daily verse appear in the guest shell (§9.6).
- Rationalising `role` into a real authority model, or removing it (§9.1).

---

## 8. Explicitly unchanged

Church list screen, members screen and its approval flow, church tab shell,
Home/For You section behaviour inside a church, Studio, dashboard, super-admin
flows, onboarding, and the placement of Bible/favorites inside the church shell.

---

## 9. Critical correctness notes

**Read this section before writing code.** Each item causes a security bug, data
loss, or a broken church if implemented naively.

### 9.1 — `role` is NOT authorization

`AppUser.role` is read only for display and analytics
(`settings_screen.dart:884,1043,1070`) and set to `'admin'` during church
seeding (`super_admin_church_service.dart:353`). **Real authority comes from
three separate sources that must never be inferred from one another:**

- **Member** — `approved == true` on the membership doc.
- **Church admin** — the signed-in email appears in `churches/{cid}/config/app.admins`. Checked against `firebaseUser.email` (see `app_entry.dart`), **never** against a Firestore profile field.
- **Super admin** — an enabled record in the global `superAdmins` collection.

Do not use `role` for any access decision, and do not "fix" it into one.

### 9.2 — `display*` fields have two different meanings

- **Linked member** (`linkedUid` set): a read-only **cache** of `users/{uid}`, written only by the Phase 6 fan-out. Clients must be denied write access in rules, or the cache stops being trustworthy.
- **Unlinked member** (`linkedUid == null`): the **authoritative** profile, because no identity doc exists.

The fan-out must skip unlinked rows or it will wipe admin-entered data.

This is why admin member lists work unchanged, and the reason is stronger than
"convenience". Member search (`members_repository.dart:40`) is **server-side**:

```dart
collectionRef().orderBy(searchField).limit(25)
  .startAt([q]).endAt(['$q'])   // prefix range
  .startAfterDocument(cursor)          // pagination
```

`_searchFieldForQuery` (`:480`) picks `email` when the query contains `@`,
`phone` when it looks numeric, otherwise `name`. Ordering, prefix matching and
cursor pagination all execute on the member collection. **Joining `users/{uid}`
per member is not merely slow here — it is impossible**, because you cannot
order or paginate on a field that lives in another document.

**Therefore search must be repointed at the cached fields:** `displayName`,
`displayEmail`, `displayPhone`. Update `_searchFieldForQuery` and the `orderBy`
accordingly. Firestore creates single-field indexes automatically, so no
explicit index entries are needed for these, but verify the prefix queries
return results after the rename.

`watchGroupMembers` (`:106`) likewise does `orderBy('name')` on group rows, so
those denormalised names must stay fresh — covered by the Phase 6 fan-out.

### 9.3 — Unlinked members are a feature; linking must merge by field owner

A church directory legitimately contains people who never use the app — elderly
members, children, historical records. `requestAccess` creates these with a
**random Firestore id** when `createChurchMemberWithoutAuth` is set
(`firestore_authentication.dart:321`). **Do not "clean them up."**

`MembersRepository.attachFirebaseAuthToMember` (`members_repository.dart:265`)
**re-keys** such a doc to the real auth uid when the person gets an account.
This must stay a re-key — see §9.7.

Today linking is only ever admin-driven (`create_auth_account_screen.dart:193`).
Under D5 a person can now **self-sign-up** with an email a church already holds
as an unlinked member, producing two records for one human. Request-access must
check the target church for an unlinked member with a matching email and
**link** rather than create.

**Merge direction differs by field owner:**

- **Identity fields** (name, phone, dob, gender, address…) → **the person's own data wins.** Self-reported and current.
- **Church-specific and church-attested fields** (category, familyId, groups, baptism records, membership status/notes, financial) → **the admin's data wins.** The person never had access to enter these.

Reversing this either blanks a church's baptism records or overwrites someone's
corrected details with an admin's stale typo.

**Known gap:** if the person signs up with a different email than the admin
recorded, no link happens and the duplicate stands. Recovery is a manual link
action — deferred (§7).

### 9.4 — Doc ids are inconsistent today

The member collection holds a mix of auth uids and random ids (§9.3). Group
member rows are sometimes keyed by **email** —
`super_admin_church_service.dart:367` uses the admin's email when no uid exists.
Normalise group rows to uid during the Phase 2 re-key.

**Never mint `users/{randomId}`.** Identity docs exist only for real auth uids.

### 9.5 — `dayStreak` type drift

Written as a **`String`** by `AppUser.toMap()`, read as num-or-string by
`_parseDayStreak`. Normalise to `int` during backfill, or streaks silently reset.

### 9.6 — Daily verse cannot work church-free

`dailyVerseProviderLocal` (`daily_verse_providers.dart:7`) reads
`appConfigProvider`, which returns `AppConfig.fallback()` with no church — and
`DailyVerseRef.empty()` is book `''`, chapter `0`, verse `0`
(`app_config_model.dart:160`). `getVerse` gets nothing. Keep daily verse out of
the guest shell unless a global default verse is added (§7).

### 9.7 — The membership doc id must equal the auth uid

Firestore rules **cannot query** — only `get()` a constructible path:

```
function isApprovedMember(churchId) {
  return exists(/…/churches/$(churchId)/users/$(request.auth.uid)) && …
}
```

A `linkedUid` pointer on a randomly-keyed doc cannot be resolved by any rule, so
`isApprovedMember()` — which guards ~20 rule blocks — would deny the member
access to their own church. A lookup-index workaround would cost **two** `get()`s
in the most frequently evaluated function in the ruleset.

**Therefore re-keying stays.** The split makes it far cheaper: identity, reading
plans and learning progress no longer move, so only a small fixed-size
membership doc and its group rows are copied.

### 9.8 — Rules `get()` budget

`isApprovedMember()` already costs a document read per rule evaluation. Do not
add a second `get()` into `users/{uid}` in any hot rule. That is precisely why
`display*` exists.

### 9.9 — Collection-group rule must match on the field

The `members` group read rule must test `resource.data.uid`, not the doc id, or
Firestore rejects the query. Cover with rules unit tests before Phase 3 depends
on it.

### 9.10 — Localization

Per `AGENTS.md`, no user-visible string may be a raw Dart literal. Every new
string (profile step, guest shell, completion prompt, approval loader) needs a
key in `defaultChurchTextContents` rendered via `context.t()` / `ref.t()`.
Guest-shell copy goes in `defaultChurchTextContents`, not
`preAuthDefaultTextContents` — `TextContent.fromMap(null)`
(`app_config_model.dart:258`) merges both when no church is selected, and
churches never override guest copy.

### 9.11 — Abandoned identities

D5 creates `users/{uid}` before any church request, so people who sign up and
never join leave orphan identity docs. Harmless, but worth a periodic sweep and
a super-admin count.

---

## 10. Blast radius

Twelve Dart files touch the user paths:

```
services/side_drawer/members_repository.dart          5 refs
services/firestore/firestore_paths.dart               3
services/firestore/firestore_authentication.dart      3
services/church_user_repository.dart                  2
screens/select-church-screen.dart                     2
screens/entry/login_entry_screen.dart                 2
providers/user_provider.dart                          2
widgets/feed_card_widget.dart                         1
services/super_admin/super_admin_church_service.dart  1
services/studio/studio_repository.dart                1
screens/for_you/sections/article_section.dart         1
screens/entry/login_request_screen.dart               1
```

Entry flow: `create_auth_account_screen.dart` (profile step),
`login_request_screen.dart` (member mode shrinks), `app_entry.dart` (gate),
`app_bootstrap.dart` (streak), Profile screen, new guest shell under
`screens/personal/`.

Backend: `functions/src/index.ts` (701, 746, 1091),
`functions/src/financial.ts:375`, new fan-out and lifecycle functions,
`functions/scripts/migrate/`.

Config: `firebase.json` (multi-database), `firestore.rules`, `storage.rules`,
`firestore.indexes.json`.

Docs to update in the same change, per the documentation policy:
`architecture/system-architecture.md`, `features/churches-and-membership.md`,
`features/authentication-and-entry.md`, `features/navigation-profile-settings.md`,
`features/members-families-groups.md`, `features/notifications.md`,
`features/bible-and-favorites.md`, `features/bible-learning.md`,
`features/super-admin.md`, `testing/README.md`.

---

## 11. Test plan

Four of 27 existing test files touch these paths:
`production_hardening_test.dart`, `user_quick_card_test.dart`,
`profile_photo_model_test.dart`, `dashboard_gender_members_screen_test.dart`.

No mocking library is in use — follow the existing real-objects-and-fakes
pattern (`CLAUDE.md`).

| Area | Cases |
|---|---|
| Models | Identity/membership round-trip; `dayStreak` accepts both types; `phone`/`contact` merge |
| Signup | Profile step shown once; identity written before any church; resumable if abandoned |
| Request access | Second church asks only church-specific fields; links to an unlinked member by email; merge direction correct per §9.3 |
| Guest shell | All four no-membership situations route to it; church content absent; streak ticks; multiple pending requests coexist |
| Approval | Loader covers repaint; user state carries; church content appears |
| Learning split | Global module completion writes personal progress and **no** church result; church module completion writes both; global progress survives leaving a church and appears in the next one; guest completion later visible inside a church |
| Backfill | uid vs random-id resolution; conflict rule per field; streak collapse; `profileComplete` derivation; learning-progress split by module source; orphan module ids dropped and logged; idempotent re-run |
| Rules | Collection-group `members` read; `display*` client write denied; member cannot flip `approved`; member cannot read `financialStabilityRating`/`membershipNotes` |
| Lifecycle | Leave church keeps identity/favorites/plans; delete church keeps users; delete account removes everything |
| Notifications | Token refresh reaches all memberships; non-selected church delivery (regression for §2.6) |

Re-run existing flows: CHURCH-01…CHURCH-12, BIBLE-06/07, and the member and
dashboard flows in `features/members-families-groups.md` and
`features/dashboard.md`.

Release gate (`CLAUDE.md`):

```
flutter analyze lib/church_app test
flutter test
npm --prefix functions run lint && npm --prefix functions run build
```

---

## 12. Open items

None blocking. All decisions are recorded in §1.

### Addendum (found during Phase 1 implementation)

**§5.1's display* cache was too narrow for members_screen.dart.** That
screen's bulk search filters on `email`, `phone`, `maritalStatus`,
`educationalQualification`, `talentsAndGifts` across the whole roster, and
its birthday/anniversary widgets sort/filter the whole roster by `dob` and
`weddingDay` — none of `weddingDay`, `maritalStatus`,
`educationalQualification`, `talentsAndGifts` were in the original 7-field
display* list, and per §9.2 a per-member join for a bulk list is
impossible, not just slow. Confirmed with the owner: extend the cache
rather than accept the regression. `ChurchMembership` now also carries
`displayWeddingDay`, `displayMaritalStatus`,
`displayEducationalQualification`, `displayTalentsAndGifts`,
`displayLocation`, `displayAddress` — same cache-vs-authoritative semantics
as the original display* fields (§9.2), same client-write-denied guard,
same Phase 6 fan-out target once that function exists. `contact` needed no
equivalent — D8 already merged it into `phone`. (`displayLocation`/
`displayAddress` were added slightly later than the first four, while
migrating `login_request_screen.dart`'s admin edit form — same gap, same
fix, not a separate decision.)

Also found while rewriting firestore.rules' `members` update rule for this:
the first version let *staff* write display* fields unconditionally, which
defeats the whole point of §9.2 for a *linked* member (the cache stops
being trustworthy the moment any client can write it). Fixed: staff may
only touch display* when the row is unlinked (their own authoritative
data); for a linked row, only the Phase 6 fan-out (Admin SDK, bypasses
rules) may.

### Addendum (found during Phase 0 rules re-verification against migrationv1)

Testing the app against `migrationv1` surfaced that the Phase 1 `members`
collection-group read rule had only ever been deployed to `migrationv1`
during the original Phase 0 write-verification step — before that rule
existed. `myMembershipsProvider`'s `collectionGroup('members')` query
(§5.2/entry gate) failed with `PERMISSION_DENIED` on first real run.
Redeployed rules+indexes to `migrationv1` only, using the documented
single-object `firebase.json` workaround, then reverted `firebase.json`
back to array form (`git diff` clean). No production/`(default)` rules were
touched. **Going forward in this migration, `firestore.rules` and
`firestore.indexes.json` are edited locally as each phase needs them, but
are not deployed** — deployment (to `migrationv1` for continued testing,
and to production only at Phase 8) is left as an explicit, separate step
for the repo owner to run and verify against the console themselves.

### Addendum (self-service request-access simplification, post-Phase-3 feedback)

Once `CompleteProfileScreen` exists, the self-service request-access screen
never needs to re-collect identity fields — `RequestChurchAccessScreen`
(`screens/entry/request_church_access_screen.dart`) reads them from
`users/{uid}` and submits with one tap, guarding against double-submission
by checking the membership doc immediately before writing. This replaces
`login_request_screen.dart`'s member-mode path referenced in §5.5's form
split table; `adminCreateMode` is untouched. See
`KT Files/features/authentication-and-entry.md` for the user-facing
flow, and `helpers/self_signup_membership_helper.dart` for the
category/family-id derivation shared by both screens.

The Learning tab was also dropped from the guest shell (§5.3) on direct
feedback — Church Tree modules remain reachable inside any joined church,
just not in the pre-approval hub. `globalPublishedLearningModulesProvider`
was removed as a result; `LearningModuleRepository.watchPublishedModules()`
stays, since Phase 4's learning-track split (§5.6) still needs it to
classify a module id as global vs. church.

**Deliberately deferred, not forgotten:** §5.5's "Profile, after approval"
step and its non-blocking prompt-sheet UI
(`widgets/prompts/prompt_sheet.dart` / `prompt_sequence_provider`) for
`maritalStatus`/`weddingDay`/`educationalQualification`/`talentsAndGifts`.
`UserIdentityRepository.updateProfile` already accepts all of these fields
end-to-end — only the prompt-sheet trigger and its own settings-screen UI
surface are missing. Lower risk to leave for a follow-up pass than the
remaining data-model phases (2, 4, 6, 7), since nothing currently writes
bad data here — the fields are just not yet reachable through this
specific UI, and are surfaced when the admin captures them directly (form
edit modes on the church staff side).

### Addendum (Phase 0/2 harness built)

`functions/scripts/migrate/` implements the backfill harness and the full
Phase 2 logic: `cli.ts` (flag parsing — `--database` required with no
default, refuses `--write` against `(default)`), `identity.ts`
(cross-church field-merge/conflict resolution), `moduleSource.ts`
(global-vs-church module/section classification, cached per church),
`migrate.ts` (orchestration: identity merge, membership write, learning
progress split, `learning_results` tagging, `readingPlans` move,
`groups/{gid}/users` -> `groupMembers` re-key), and `report.ts` (JSON run
report + conflicts CSV, always written — including on a dry run). Added
`scripts` to `functions/tsconfig.json`'s `include` and an `npm run migrate`
script per "reusing the existing functions toolchain" — `npm --prefix
functions run lint && npm --prefix functions run build` already covers it.
Usage and the credential setup it needs are in
`functions/scripts/migrate/README.md`.

**Two gaps found against the spec text while implementing, both
documented in the script/README rather than silently resolved:**

1. §5.1's "newest `updatedAt` wins" conflict rule assumes an `updatedAt`
   field that does not exist on the pre-migration data (confirmed by
   reading the actual `AppUser` shape and `learning_module_repository.dart`
   — only `createdAt` exists). The script uses `createdAt` as the best
   available recency signal instead.
2. `groups/{gid}/users` had never actually been renamed to `groupMembers`
   in the Flutter client despite §5.1 listing it as part of the D1 rename —
   `firestore_paths.dart`'s `churchGroupMembers()` was still pointing at
   `users`. Fixed alongside the harness (`firestore_paths.dart`,
   `firestore.rules`) so the harness's re-key target actually matches what
   the app now reads.

**Not run yet.** The harness type-checks, lints, and reaches its first
Firestore call correctly (verified locally against `migrationv1` with a
bogus `--church=` filter to confirm it authenticates the flags and only
then fails) — but this machine has no Google Cloud application-default
credentials configured (`firebase login`'s session is a different,
incompatible credential type), so the actual dry run against `migrationv1`
has not executed. Needs `gcloud auth application-default login` or a
service account key — see the script's README — then:
`cd functions && npm run migrate -- --database=migrationv1`, review the
report and conflicts CSV, re-run until stable, then add `--write`.

### Addendum (Phase 4 complete except avatar blob copy)

- **Reading plans** moved onto the identity: `ReadingPlanProgressRepository`/
  its provider now target `users/{uid}/readingPlans` and no longer require a
  selected church. Deleted the now-dead `churchUserReadingPlans` path
  helper.
- **Favorites** moved onto the identity, SharedPreferences kept as the
  offline cache per §6: new `FavoritesRepository` writes
  `users/{uid}/favorites`; `FavoritesNotifier.loadFavorites()` merges any
  local-only key into Firestore on every load (handles first sync and any
  offline gap); `toggleGlobalHighlight` writes through to both;
  `clearAll()` (called on logout) clears only the local cache — Firestore
  favorites are person-owned and must survive a logout, not be deleted by
  one.
- **Learning split (§5.6, D9) implemented as a real behaviour change**, not
  just a path move: `LearningModule` gained a `source` (`global`/`church`)
  field set by the repository at load time from which collection it
  queried (a church's own customization of a global module —
  `sourceModuleId` set — is still `church`, since it lives under that
  church's collection). `submitSectionQuiz`, `completeSection`, and
  `submitModuleExam` now take `source` and route accordingly: global →
  `users/{uid}/learning_progress`, no results row; church →
  `churches/{cid}/members/{uid}/learning_progress` (fixed off the stale
  `churchUserLearningProgress`/`churches/{cid}/users/...` path in the same
  change) plus a `learning_results` row tagged `source: 'church'`.
  `watchProgress` now merges `watchGlobalProgress` + a new
  `watchChurchMemberProgress` via a pure `mergeLearningProgress` function
  (unit tested) so the member UI's single merged module list gets a single
  correctly-sourced progress view. The now-fully-dead
  `churches/{cid}/users/{uid}` nested rules block (readingPlans,
  learning_progress) was removed from `firestore.rules` — every former
  consumer has moved.
- **Avatars**: the person's own photo already uploads to
  `users/{uid}/profile/...` (done in earlier Phase 3 work). **Not done:**
  §6's "copy blobs, rewrite `profilePhotoUrl`" for existing users whose
  `profilePhotoUrl` still points at the old
  `churches/{cid}/users/{uid}/profile/...` Storage path. Deliberately
  deferred — the cost of getting a Storage blob copy + Firebase download
  URL reconstruction wrong (wrong bucket path, a stale/invalid download
  token) is a broken avatar image, not data loss or a security gap, and
  it's a strictly smaller, more isolated piece of work than Phases 6/7.
  `storage.rules`' dual-path block (both the old and new
  `.../profile/{allPaths=**}` matches) stays in place indefinitely as
  compatibility for these un-migrated blobs rather than being removed on
  the assumption every caller has moved — unlike the Firestore paths
  above, this one genuinely hasn't. A user who re-uploads their photo via
  Edit Profile lands on the new path immediately; existing photos just sit
  on the old one until either they re-upload or someone writes the
  blob-copy pass.

### Addendum (Phase 6 fan-out function built, not deployed)

`functions/src/identityFanout.ts` exports `fanOutIdentityChanges`, a single
`onDocumentWritten('users/{uid}')` trigger replacing all client-side
denormalisation (§6 Phase 6):

- Diffs the full extended display* field set (§5.1's addendum list —
  name/email/phone/photo/dob/gender/weddingDay/maritalStatus/
  educationalQualification/talentsAndGifts/location/address) between
  before/after; short-circuits entirely when nothing in that set changed
  (a write to `dayStreak` or `lastActiveChurchId`, say, triggers no
  fan-out at all).
- Refreshes `display*` on every **linked** membership found via
  `collectionGroup('members').where('uid','==',uid)` — filtered again on
  `linkedUid === uid` as a belt-and-braces check, though an unlinked row's
  `uid` field is always `''` so it could never match the query in the
  first place (§9.2/§9.3).
- Only when `name` or `profilePhotoUrl` specifically changed (not e.g. an
  address edit, which none of these collections display), additionally
  updates the denormalised author fields on that person's `feeds`
  (collection group, field names `userName`/`userPhoto`), `globalFeeds`
  (root collection, same field names), `groupMembers` (collection group,
  `name`/`profilePhotoUrl`), `faith_engagement` (collection group,
  `userName`/`userPhotoUrl`), and `learning_results` (collection group,
  `userName` only — no photo field there).
- Every write is batched at Firestore's 500-per-batch limit and uses
  `.set(..., {merge: true})`.
- Added the four matching `firestore.indexes.json` fieldOverrides needed
  for the new collection-group queries (`groupMembers.uid`, `feeds.userId`,
  `faith_engagement.userId`, `learning_results.userId`) — same
  COLLECTION_GROUP-scope pattern as `members.uid`/`devices.uid`.
- Checked `UserIdentityRepository.updateProfile` for the "delete
  updateProfile's manual photo fan-out" bullet: there was nothing to
  delete — that repository was written fresh in Phase 3 and never
  included one; the bullet describes the pre-migration
  `ChurchUsersRepository`, already deleted in Phase 1.

**Not deployed.** Same reasoning as the rules/indexes above — a Cloud
Function that fires on every `users/{uid}` write is exactly the kind of
change the repo owner should trigger deliberately (`npm --prefix functions
run deploy`, or scoped with `--only functions:fanOutIdentityChanges`), not
something done autonomously mid-migration. `npm --prefix functions run
lint && npm --prefix functions run build` both pass.

### Addendum (Phase 7 lifecycle built, not deployed)

Three callable functions in `functions/src/lifecycle.ts` (all
`us-central1`, exported from `index.ts`):

- **`leaveChurch({churchId})`** — deletes the caller's own membership doc,
  its `learning_progress` subcollection, and its rows in that church's
  `groups/*/groupMembers`. Identity, favorites, reading plans, Church Tree
  progress and streak are untouched (all live on `users/{uid}`).
- **`deleteChurch({churchId})`** — super-admin only (checked against
  `superAdmins` by the caller's token email, same pattern as
  `_requireSuperAdmin()` elsewhere). Uses Admin SDK's
  `firestore.recursiveDelete()` on the `churches/{churchId}` doc — this
  alone handles every subcollection at any depth (members, groups, feeds,
  prayer requests, learning content, all of it) without needing to
  enumerate them by hand. Also best-effort deletes the
  `churches/{churchId}/` Storage prefix. Users survive — nothing outside
  that subtree is touched.
- **`deleteAccount()`** — no params; always acts on `request.auth.uid`.
  Requires the ID token's `auth_time` to be within 5 minutes (the client
  calls `reauthenticateWithCredential` immediately before invoking this,
  which refreshes it — the server-side half of the same "recent password
  re-entry" guarantee the old client-only flow provided). Finds every
  membership via `collectionGroup('members').where('uid','==',uid)`,
  deletes each one's `learning_progress` + `groupMembers` rows + the
  membership itself + a best-effort Storage prefix delete for that
  church's legacy avatar path, then deletes `users/{uid}` and its
  subcollections, the person's `users/{uid}/profile/` Storage prefix, and
  finally the Auth user itself via `admin.auth().deleteUser(uid)`.

**Client wiring, closing the "no account-deletion UI" release blocker**
(`KT Files/testing/android-release-readiness-2026-08-13.md`):
`firestore_authentication.dart`'s `deleteAccount()` was rewritten to
reauthenticate then call the callable, replacing its old TODO-marked
partial client-side cleanup (own membership + identity only, silently
missed every other church). Added a real "Delete account" section to
Settings (password-confirmation dialog) and a "Leave church" section
(shown only when a church is selected) — both were previously fully
unbuilt; `deleteAccount` had no UI caller at all before this. Added a
"Delete church" action to `CreateChurchScreen`'s edit mode (super admin
only, type-the-church-name-to-confirm given `recursiveDelete` is
irreversible), backed by a new `SuperAdminChurchService.deleteChurch`.

**Not deployed** — same reasoning as Phases 5/6: these are exactly the
kind of irreversible, cross-church operations that should be deployed and
smoke-tested deliberately by the repo owner, not as a side effect of this
session. The UI is wired and will call the callable correctly once
`npm --prefix functions run deploy` runs; until then, tapping these
actions in a running app will fail with a "function not found" error —
expected, not a bug.

### Addendum (two real bugs found while attempting the first live deploy)

**1. Cross-database Auth-deletion risk.** `fanOutIdentityChanges`,
`leaveChurch`, `deleteChurch`, `deleteAccount`, and the Phase 3/5 edits to
`rebuildChurchDashboardMemberMetrics`/`ensureFinanceGroupMember`/
`sendFeedPostNotification`/`sendPrayerRequestAdminNotification` all called
`admin.firestore()`, which always resolves to the `(default)` database —
never `migrationv1`, regardless of which database the Flutter client is
configured against. Firebase Auth is project-wide, not per-database, so
testing `deleteAccount` from a client pointed at `migrationv1` would have
looked up Firestore data in the wrong (production) database, found
nothing there, and *still deleted the real, project-wide Auth account* at
the end. Caught before any deploy happened.

Fixed with `functions/src/firestoreDb.ts`: a `FIRESTORE_DATABASE_ID`
functions parameter (`defineString`, default `(default)`) plus a
`firestoreDb()` accessor, mirroring the Flutter client's own
`FIRESTORE_DATABASE_ID` build-time override. Every Firestore-triggered
function this migration touches now also carries `database:
firestoreDatabaseIdParam` in its trigger options (`fanOutIdentityChanges`,
`rebuildChurchDashboardMemberMetrics`, and — since they invoke the
Phase 5 fan-out fix and are part of the test checklist —
`notifyChurchAdminsOnPrayerCreated` and `processQueuedChurchNotification`
too). Deliberately scoped to only these; unrelated existing triggers
(recurring events, password reset, YouTube live, etc.) were left
untouched to avoid widening the blast radius of this migration into
already-stable code. Set `FIRESTORE_DATABASE_ID=migrationv1` in
`functions/.env.flutterlearning-c9f6c` before deploying for this testing
phase; remove it (or reset to `(default)`) before any production deploy —
same flip-and-revert pattern as `firebase.json`'s array-form workaround.

**2. `npm run build` was silently producing undeployable output since
Phase 0.** Adding `scripts` alongside `src` to `tsconfig.json`'s `include`
(to get the migration harness covered by the existing lint/build
toolchain) changed TypeScript's inferred `rootDir` to the common parent of
both (`functions/`), which shifted every compiled path down one level —
`lib/index.js` became `lib/src/index.js`. `npm run build` kept reporting
success all night because there were no type errors; only the *output
location* was wrong, silently breaking `package.json`'s `"main":
"lib/index.js"` — the Cloud Functions deploy entry point. The Phase 2
backfill was unaffected (it was always invoked at the coincidentally-still
-correct nested path, `lib/scripts/migrate/run.js`, directly), but every
function added or edited since Phase 0 (`fanOutIdentityChanges`,
`leaveChurch`, `deleteChurch`, `deleteAccount`, the `rebuildChurch
DashboardMemberMetrics`/notification edits) was invisible to `firebase
deploy` — it would have silently deployed only the pre-migration
functions.

Fixed by giving the migration scripts their own project:
`tsconfig.scripts.json` (`rootDir`/`include`: `scripts`, `outDir:
lib-scripts`), `package.json`'s `migrate` script now runs `tsc -p
tsconfig.scripts.json` before invoking `lib-scripts/migrate/run.js`, and
`.eslintrc.js`'s `parserOptions.project` lists both tsconfigs so lint
still covers everything. `tsconfig.json` reverted to `include: ["src"]`
only. Verified with a clean rebuild (`rm -rf lib lib-scripts`) that
`lib/index.js` is flat again and exports all four new functions, and that
`lib-scripts/migrate/*.js` builds independently.

**Lesson for future phases:** "lint and build pass" was not sufficient
verification for a deploy-affecting change — checking the actual output
file layout against what `package.json`/deployment expects would have
caught this immediately instead of at first-deploy time.

### Addendum (brief production impact during the first live deploy — 2026-09-09)

The first deploy of the 7 migration-related functions
(`leaveChurch`/`deleteChurch`/`deleteAccount`/`fanOutIdentityChanges` new,
plus `rebuildChurchDashboardMemberMetrics`/`notifyChurchAdminsOnPrayerCreated`/
`processQueuedChurchNotification` updated) used
`FIRESTORE_DATABASE_ID=migrationv1` for all seven. The first three are new
and had no production traffic, but the latter three are **pre-existing,
already-live production functions** — deploying them with `database:
migrationv1` redirected their Firestore triggers away from `(default)`,
meaning for roughly the few minutes between that deploy and the fix
below, any real production church-member write, prayer request, or queued
notification would not have triggered dashboard-metrics rebuilds or
prayer/notification delivery.

Caught immediately after the first deploy completed (before any real
production writes were confirmed to have been missed) and fixed by
redeploying just those three back with `FIRESTORE_DATABASE_ID=(default)`
explicitly set — omitting the variable entirely errors in non-interactive
deploys once a function references the parameter in its trigger config
("no value for FIRESTORE_DATABASE_ID"), so `functions/.env.flutterlearning
-c9f6c` now keeps an explicit `FIRESTORE_DATABASE_ID=(default)` line
rather than leaving it unset.

**Verified after the fix:** `fanOutIdentityChanges` live-tested against
`migrationv1` — updated an identity's `name`, confirmed the linked
membership's `displayName` updated within ~8 seconds, reverted, confirmed
it reverted too.

**Lesson:** when a single "logical unit" of functions mixes brand-new
(no-traffic) and pre-existing (live-traffic) functions, deploy them
separately with different `FIRESTORE_DATABASE_ID` values rather than one
combined `--only` deploy — the new ones can safely point at the test
database while the existing ones stay pinned to `(default)` throughout,
with no window where production is misdirected at all.

### Addendum (real entry-gate bug found during end-to-end testing)

First-login-on-a-fresh-device (or after clearing app data) landed
approved users on an infinitely-loading `ChurchTabScreen` — every section
hung rather than erroring. Manually entering a church via Settings ->
Switch church worked fine, isolating the bug to the *auto-enter* path
specifically, not `ChurchTabScreen` itself.

**Root cause:** `AppEntry._restoreSelectedChurchIfNeeded()` only ever
checked local device storage (`ChurchLocalStorage`) for a previously
selected church. On a genuinely fresh install — nothing in local storage
yet — it silently did nothing, leaving `selectedChurchProvider` (and so
`currentChurchIdProvider`) null underneath `ChurchTabScreen`, whose every
section depends on a resolved church id. `UserIdentity.lastActiveChurchId`
existed on the model specifically to cover this case (§5.1) but was never
read by the entry gate, and `UserIdentityRepository.setLastActiveChurchId`
was never called by anything — both sides of that field were dead code.

**Fixed:** `_restoreSelectedChurchIfNeeded` now takes the resolved
identity and the approved memberships list, and falls back through: local
storage -> `identity.lastActiveChurchId` (if it's still one of the
person's approved churches) -> the earliest-joined approved membership.
Whichever church gets picked — here or through the three manual
"enter/switch church" flows (`select-church-screen.dart`,
`guest_shell_screen.dart`'s "Your churches" tap, `request_church_access
_screen.dart`'s post-approval entry) — now also calls
`setLastActiveChurchId`, so a person's choice follows them to their next
device, not just this one.

Reproduced against `migrationv1` with a real fresh install (`pm clear` on
the emulator) before writing the fix; re-verification after the fix is
pending the next test pass.

**Revised on user feedback after seeing the fix live:** silently
auto-picking the earliest-joined approved membership when nothing was
resolvable was the wrong call for first-ever entry — it guesses on the
user's behalf when there's more than one approved church. Replaced with:
`AppEntry` now checks whether a church is resolvable at all
(`_resolvableChurchId` — local storage or `lastActiveChurchId`, unchanged)
and, if not, renders `SelectChurchScreen` (the existing "Your churches /
Other churches" picker, previously only reachable via Settings > Switch
church) instead of guessing. Picking an approved church there sets
`lastActiveChurchId` (already wired per the fix above), so every later
launch resumes it directly without the picker — the picker is a one-time
thing per account, not a permanent hub. The "earliest-joined" auto-pick
tier was removed from `_restoreSelectedChurchIfNeeded` entirely, since
that helper is now only ever reached once a church is already known to be
resolvable.

### Addendum (both Phase 4 deferred items closed, plus a real bug found doing so)

**Profile-completion UI:** `_EditProfileSheet` (Settings > Edit Profile)
now has fields for maritalStatus (dropdown), weddingDay (date picker,
shown only when married — matching `login_request_screen.dart`'s existing
pattern), educationalQualification, and talentsAndGifts (comma-separated).
No repository changes needed — `UserIdentityRepository.updateProfile`
already accepted and wrote all four; only the UI was missing.

**Avatar blob copy — and a real bug found while building it:**
`identity.ts`'s cross-church merge never included `profilePhotoUrl` at
all — `MergedIdentity` had no such field, so **every identity written by
the Phase 2 backfill silently lost the person's avatar**, even though the
old per-church rows had it. Fixed: `profilePhotoUrl` is now merged the
same way as `name`/`phone` (newest wins, conflict-logged).

Separately, added `functions/scripts/migrate/avatarBlob.ts`
(`migrateAvatarBlob`) — for each identity with a `profilePhotoUrl` still
pointing at the old `churches/{cid}/users/{uid}/profile/...` Storage path,
copies the blob to `users/{uid}/profile/...`, sets a fresh download token,
and rewrites the URL; a no-op for anything already on the new path, an
external URL, or empty. Storage is project-wide (not per-database), so
this runs against the one real bucket regardless of which Firestore
database the run targets — verified against the one real avatar in the
production bucket (found via a live `getFiles` scan), which correctly
copied to the new path with a working rewritten URL after `--write`.

Re-ran the full `--write` backfill once both fixes landed — safe and
idempotent, since every write is fully recomputed from source each run,
never incrementally merged. **Unrelated to either fix:** this re-run also
showed the church count drop from 22 to 19 — confirmed with the repo
owner that this was their own deliberate cleanup of three empty test
churches via the new super-admin Delete church button, not a bug (and a
nice confirmation that `deleteChurch`'s `recursiveDelete` works correctly
in the wild).

### Addendum (three more real bugs found in end-to-end testing)

**Access-control gap:** an unapproved membership could still land the
person in `ChurchTabScreen` for that church, as long as they were
approved somewhere else. `SelectChurchScreen._handleContinue` set
`selectedChurchProvider` to whatever was tapped in "Your churches"
regardless of approval — that list includes every membership, not just
approved ones — and `AppEntry`'s resolver trusted `selectedChurchProvider`
unconditionally. Fixed both ends: `_handleContinue` now shows a "still
pending" message and returns without touching
`selectedChurchProvider`/navigating when the tapped membership isn't
approved; `AppEntry._resolvableChurchId` now checks every candidate —
including the already-selected church — against the approved list rather
than trusting it blindly, as defense in depth (§9.1: membership existing
is never authorization on its own).

**Stale UI after leaving:** `userChurchesProvider` (a `FutureProvider`)
was never invalidated after `leaveChurch()` ran, so Settings > Switch
church's "Your churches"/"Other churches" lists stayed stale until some
unrelated rebuild happened to refetch it. Added the invalidation.

**Admin allowlist not cleaned up on leave/delete:** found via a direct
question from the repo owner, not a live repro — `leaveChurch` and
`deleteAccount` deleted the membership row but never touched
`churches/{cid}/config/app.admins`. Since `isChurchAdmin(churchId)` checks
that allowlist directly (`myEmail() in .../config/app.data.admins`) with
no dependency on an existing membership at all, someone who left a church
while listed as one of its admins would keep passing `isChurchAdmin` for
it indefinitely — exactly the kind of authority-not-re-derived-from-
membership gap §9.1 warns about, just for the admin allowlist specifically
rather than `role`. Fixed: both functions now best-effort remove the
person's email from that church's admin list (case-insensitive match
against whatever casing is actually stored, since `arrayRemove` needs an
exact value match) whenever they leave or their account is deleted.
`deleteChurch` needed no equivalent fix — it deletes `config/app` along
with everything else in the subtree.

### Addendum (the same "unconditional selectedChurchProvider" bug found in a second, live place)

Reported live: leaving a church, then re-requesting, showed `approved:
false` in Firestore yet the app still behaved as if entered. Audited
every call site that sets `selectedChurchProvider` in the codebase
(`grep -rn "selectedChurchProvider.notifier).state ="`). Found the exact
same class of bug as the earlier `SelectChurchScreen` fix, in
`RequestChurchAccessScreen._enterChurch` — it unconditionally set
`selectedChurchProvider`/local storage regardless of the `approved`
parameter passed in, for both the "already requested" (existing doc) and
the fresh-request paths.

Fixed by making `_enterChurch()` take no parameter and only ever be
called for an approved outcome; the pending case now shows a clear
"request submitted, waiting on admin approval" message and re-enters the
normal `AppEntry` gate via a new `_returnToEntryGate()` — which, thanks to
the earlier `_resolvableChurchId` fix, correctly lands on the picker or
guest shell rather than any specific church.

The same pattern also exists in `login_request_screen.dart`'s
self-signup (`!adminCreateMode`) branch, confirmed dead: audited every
caller of `LoginRequestScreen` and all of them pass `adminCreateMode:
true` (the admin-create-member path) except two screens
(`login_entry_screen.dart`, `auth_options_screen.dart`) that nothing in
the app navigates to anymore — leftover from before the Phase 3 entry-flow
rewrite. Not fixed since it's unreachable, but flagged as a dead-code
cleanup candidate for a future pass.

### Addendum (guest shell removed — consolidated into SelectChurchScreen)

Per direct user feedback, `GuestShellScreen` (the "no approved membership
anywhere" landing screen — Bible tab + a "My Churches" tab with its own
Your churches/Your requests/Browse churches sections) was removed entirely.
`AppEntry`'s `approvedMemberships.isEmpty` branch now returns
`SelectChurchScreen` directly — the same screen already used for the
first-ever-approval case — instead of a separate hub. This also drops guest
Bible access (the offline Bible-download tab) for someone with no approved
church; confirmed with the user as an accepted tradeoff rather than an
oversight. `SelectChurchScreen`'s "Your churches" list is unfiltered by
`approved` (a plain `collectionGroup('members')` lookup), so a pending
membership still appears there; tapping it hits the same "still pending"
guard `_handleContinue` already had from the earlier access-control fixes
above, so nothing new had to be added for that case. `guest_shell_screen.dart`
was deleted; `bible_library_screen.dart` itself was left alone since it's
still used from the drawer for approved members.

### Addendum (found and fixed via a Maestro end-to-end run: production rules
gap, a super-admin tab mislabel, and two harmless UI/test-selector quirks)

Built a reusable regression flow, `.maestro/auth_flow.yaml`, covering the new
email-first auth screen end to end: fresh signup -> complete profile ->
lands on `SelectChurchScreen`; logout -> re-enter same email -> guessed
correctly as sign-in; fresh relaunch with the same email -> guessed wrong as
create-account -> self-corrects to sign-in with the explanatory message.
Ran against an Android emulator via `adb`/`maestro` (Java runtime borrowed
from Android Studio's bundled JBR, since neither was on `PATH`).

Found real things:

1. **Production rules gap (the actual root cause of "stuck on Tell us about
   you"/permission errors reported live).** A debug build with no
   `--dart-define=FIRESTORE_DATABASE_ID=migrationv1` targets `(default)`
   (by design, the safe fallback) — but `(default)`'s deployed Firestore
   rules (confirmed via the Firebase Rules REST API: ruleset
   `576e538b-...`, updated 2026-09-08) are still pre-migration, with no
   `{path=**}/members/{memberId}` collectionGroup rule at all (`migrationv1`
   has it, ruleset `df27c1a0-...`, updated 2026-09-09). Any signed-in user
   with zero memberships then gets `PERMISSION_DENIED` on
   `myMembershipsProvider`'s collectionGroup query — confirmed via device
   logcat during the first Maestro run — which presents as a never-resolving
   splash screen with no visible error, indistinguishable from a hang. This
   is not a code bug; it is the expected, unavoidable state until Phase 8
   ships the migration rules to production. Documented as a hard testing
   requirement in `KT Files/testing/README.md`. The user's own earlier
   report of `sdsdss` church "still showing" after being "removed in
   migrationv1" traces to the same root confusion — a plain debug run
   reads `(default)`, not `migrationv1`, and the `DatabaseOverrideDebugBanner`
   (present only on database-override builds) was absent from their
   screenshot, confirming their test device was pointed at `(default)`.
2. **`sdsdss` church was disabled, not deleted** — verified directly against
   both databases with the Admin SDK: identical `enabled: false`,
   `approvalStatus: 'approved'` data in both (a leftover of an earlier
   Phase-2-era mirror/backfill, still in sync). The super admin dashboard's
   "Not Approved" tab was filtering purely on `enabled`, so a church that
   was reviewed once and later manually disabled looked identical to one
   that had never been reviewed. Fixed by adding `Church.approvalStatus`
   and `isPendingFirstReview` (`registrationSource == 'public' &&
   approvalStatus == 'pending'`), and splitting `super_admin_home_screen.dart`
   into three tabs — Pending review / Disabled / Enabled — instead of two.
   `sdsdss` itself was left alone (real deletion is a call for the user to
   make, not an autonomous one).
3. Two harmless things fixed along the way while pinning down Maestro
   selector failures against `_ChurchSectionCard`: a stray trailing space in
   its title `Text('$title ')` (cosmetic, `select-church-screen.dart`), and
   the flow's own assertions needed `(?s).*text.*` wildcarding once it was
   clear Android's Semantics tree merges a card's title/subtitle/count into
   one accessibility node (Maestro's text selectors are a full-string
   regex match, not "contains").
4. `.maestro/nav_smoke.yaml` still referenced the "Go Further" tab removed
   earlier in this same pass — fixed.

All three Maestro scenarios pass end-to-end against a
`--dart-define=FIRESTORE_DATABASE_ID=migrationv1` debug build. The disposable
`qa.maestro.auth2@example.com` test account (Auth + `users/{uid}` doc) was
deleted after each run via a throwaway Admin SDK script — not left behind.

### Addendum (approval notifications, pending screen, frozen back navigation,
church-switcher modal, cross-church feed preview)

Per direct user feedback, several more flow changes:

1. **Approval notification opt-in.** `ChurchMembership.notifyOnApproval`
   (new field, defaults `false`) is set by a "Notify me when approved"
   button on the new `RequestPendingScreen` — which now replaces the old
   "already requested"/"still pending" snackbars everywhere (fresh
   non-auto-approved requests, and revisiting a church with an existing
   pending row, from both `RequestChurchAccessScreen` and
   `SelectChurchScreen`). `notifyMemberOnApproval` (functions/src/index.ts,
   a `members/{memberId}` write trigger) fires once on the `approved`
   false->true edge, only when the flag is set: direct FCM push
   (`resolveDeviceTokensByUid` — not a topic, since the person isn't a
   member yet to subscribe to one) plus a queued email through the same
   `mail`-collection pattern `queuePublicChurchRegistrationWelcome` already
   uses. No rules changes needed — self-updating a non-`approved`,
   non-`display*` field on your own membership doc was already permitted.
2. **Back navigation frozen inside a church.** `ChurchTabScreen` wraps
   itself in `PopScope(canPop: false)`. This only closes a gap that could
   have opened accidentally in the future — every actual entry into a
   church already used `pushReplacement`/`pushAndRemoveUntil` from a
   single-route stack, so there was no live bug, just no explicit guarantee.
   One real bug this surfaced: `SelectChurchScreen`'s approved-entry branch
   used `pushReplacement`, which only removes the *immediately preceding*
   route — fine when this screen was always used with nothing else on the
   stack, but wrong once it could also be pushed as a switcher modal on top
   of an active `ChurchTabScreen` (below). Fixed to
   `pushAndRemoveUntil(..., (route) => false)`, which is correct in both
   cases.
3. **Church switcher.** Settings' `_SwitchChurchSection` tile is gone;
   tapping the church name/logo in `ChurchTabScreen`'s app bar (now wrapped
   in an `InkWell` with a chevron) opens
   `SelectChurchScreen(isSwitcherModal: true)` as a `fullscreenDialog`. That
   flag swaps the entry-gate header for a close (X) action and a
   "currently in {church}" badge in place of the super-admin/logout actions
   (neither belongs mid-switch).
4. **Cross-church feed preview.** `GlobalFeedPreviewSection`
   (`widgets/global_feed_preview_section.dart`) — the same
   `globalFeedPaginationControllerProvider` and `FeedCard` Community's "All
   Churches" segment uses, shrink-wrapped (no own scrollable) instead of a
   `ListView` — is embedded on `SelectChurchScreen` below the two church
   cards, in both entry-gate and switcher-modal use. Someone still picking
   a church, or mid-switch, sees real cross-church activity instead of a
   bare list of names.

### Addendum (church switcher split into "switch" vs. "register", per follow-up feedback)

The `SelectChurchScreen(isSwitcherModal: true)` design above was replaced
before it shipped anywhere — direct feedback was that tapping the church
name should show *only* the churches the person already has access to, not
the full Your/Other-churches/feed page again. So the `isSwitcherModal`
field, its close-action/badge AppBar branch, and `_CurrentChurchBadge` were
all removed from `SelectChurchScreen` (dead code once nothing set the flag
to true), and the church-name tap in `ChurchTabScreen` now opens
`ChurchQuickSwitcherSheet` (new, `widgets/church_quick_switcher_sheet.dart`)
instead — a small bottom sheet over `myMembershipsProvider` filtered to
`approved == true`, nothing else. Settings' "Switch church" tile — removed
in the previous pass — came back as "Register for another church",
pointed at the unmodified full `SelectChurchScreen`, since discovering/
requesting a *new* church is a materially different action from switching
between ones already joined, and still needs somewhere to live.

The sheet returns the picked `Church` to its caller rather than navigating
itself: by the time a bottom sheet's own `pop()` call resolves, its context
is on the way out, so `ChurchTabScreen` (guaranteed still mounted, since it
sits underneath the sheet) performs the actual switch —
`pushAndRemoveUntil(AppEntry)`, same reasoning as the `pushReplacement` bug
fixed in the previous addendum. `GlobalFeedPreviewSection` was unaffected —
it stays on the full `SelectChurchScreen` only, confirmed to have no
create-post affordance (posting is church-scoped only, from inside
Community), which was already true before this pass — nothing to remove.

### Addendum (all-churches feed moved from an inline preview to a
dedicated full-screen viewer; "Register for another church" is root-only)

Two more refinements, again from direct feedback on the previous addendum:

1. **All-churches feed is a destination, not an inline section.**
   `GlobalFeedPreviewSection` (shrink-wrapped `FeedCard` list embedded in
   `SelectChurchScreen`'s scroll view) is deleted. In its place,
   `SelectChurchScreen`'s app bar gained an "All churches feed" action
   (next to the super-admin/logout actions) opening
   `GlobalFeedFullScreenViewer` (new,
   `screens/community/global_feed_full_screen_viewer.dart`) — the same
   Reels-style vertical-swipe viewer `CommunityFullScreenViewer` uses, but
   global-only: no "Your Church" segment (nothing to switch to — this
   screen isn't scoped to any one church) and no create-post button
   (posting stays church-scoped, from inside Community). This meant
   promoting `CommunityFullScreenViewer`'s private `_CommunityViewerPageView`
   to public (`CommunityViewerPageView`) so the new viewer could embed it
   directly — same pagination/hashtag/full-caption behaviour, no
   duplicated logic.
2. **`SelectChurchScreen` is unconditionally root-level now.** Settings'
   "Register for another church" tile switched from a normal `push` (back
   arrow to Settings) to `pushAndRemoveUntil` — this screen never has a
   back button in any of its three entry points (entry gate, register
   flow, or — not applicable here, since the quick switcher bypasses it
   entirely). Leaving it, in every case, means either entering an approved
   church or starting a request; there is no "back to what I was doing."

### Addendum (inverted: `SelectChurchScreen` is feed-first, church list
moved to a new `ChurchPickerScreen`)

Direct feedback on the previous addendum: it was backwards. The default
landing content should be the feed, with the church list one tap away —
not the church list by default with the feed one tap away. Concretely:

- `SelectChurchScreen`'s body is now `GlobalFeedListView` (new,
  `widgets/global_feed_list_view.dart`) — the cross-church feed rendered
  inline (not shrink-wrapped this time — it's the screen's only content,
  with its own pull-to-refresh and infinite scroll, mirroring
  `_CommunityFeedListView`'s global branch in `community_feed_screen.dart`
  but without a churchId or create-post banner). Tapping a post opens
  `GlobalFeedFullScreenViewer` starting at that post — it gained an
  `initialPostId` param for this (previously always started at the top).
- Everything `SelectChurchScreen` used to show directly — the "Welcome
  Home" hero, "Your churches" / "Other churches" cards, and the
  register-your-church link — moved verbatim into a new
  `ChurchPickerScreen` (same file, `_ChurchPickerScreenState` was the old
  `_SelectChurchScreenState`), reached by tapping a new church-shaped
  action in `SelectChurchScreen`'s app bar (replacing the "All churches
  feed" action from the previous addendum, which no longer makes sense
  once the feed IS the default screen). `ChurchPickerScreen` is a normal
  pushed screen (back returns to the feed) with its own plain app bar —
  the super-admin/logout actions stayed on `SelectChurchScreen` rather
  than being duplicated on both.
- `SelectChurchScreen`'s own class changed from `ConsumerStatefulWidget` to
  a plain `ConsumerWidget` (no local state left once the church-list state
  — `_showYourChurches`/`_showOtherChurches` — moved to
  `ChurchPickerScreen`).
- No external call site needed to change — `AppEntry`, Settings, and the
  admin/super-admin "back to normal flow" exits all still just reference
  `SelectChurchScreen` by name; only what that name now shows changed.

### Addendum (per-church color theming removed — one brand palette everywhere)

Unrelated to the user/church decoupling itself, but recorded here since
`KT Files/features/studio.md` points back to this addendum: `AppConfig`'s
`primaryColorHex`/`secondaryColorHex`/`backgroundColorHex`/`cardColorHex`
fields (and the `config/app.theme` Firestore data they read from), Studio's
Theme tool (`_ThemeEditor` and friends in `studio_screen.dart`,
`StudioRepository.updateThemeColors`), and the `forcePreflowThemeProvider`
gate that switched between a church's theme and a fallback were all deleted
outright — not hidden behind a flag. The whole app now builds its
`ThemeData` once, in `app_bootstrap.dart`, from a single constant pair in
the new `helpers/app_colors.dart` (`AppColors.primary` dark green,
`AppColors.secondary` orange). No migration of the old per-church Firestore
theme data was performed — those fields are simply no longer read.

### Addendum (signup email-OTP gate added after §5.5's profile step; splash
screen replaced with a plain loader)

Three unrelated follow-up requests bundled into one pass:

- **Email-OTP after signup.** `users/{uid}` gained an `emailVerified` bool
  (defaults false in `createIdentity`). `AppEntry` now checks it right after
  the existing "no identity doc -> `CompleteProfileScreen`" branch: identity
  exists but `emailVerified` is false -> `EmailOtpVerificationScreen`
  (`screens/entry/email_otp_verification_screen.dart`), before any
  membership/church resolution. This is purely additive to §5.5 — Firebase
  email+password sign-up itself is unchanged; the OTP step only gates what
  happens *after* the profile-setup write. Backend:
  `requestSignupEmailVerificationCode`/`verifySignupEmailVerificationCode`
  (`functions/src/index.ts`), modeled on the existing
  `requestPasswordResetCode`/`verifyPasswordResetCode` (same SMTP
  transporter, same HMAC-keyed-hash-of-code pattern, same 10-minute
  lifetime/60s cooldown/5-per-hour/5-attempts limits) but deliberately
  **callable** (`onCall`), not `onRequest`: the caller is already signed in
  by this point, so `request.auth.uid` is trusted for both which email to
  send to (looked up via `admin.auth().getUser(uid)`, not client-supplied)
  and whose `users/{uid}` doc gets `emailVerified: true` on success — no
  separate reset-token hand-off step is needed the way password reset needs
  one, since verifying an already-authenticated session *is* completing it.
  Challenge docs live in a new `emailVerificationChallenges` collection,
  keyed by an HMAC of the uid (not email, and not shared with
  `passwordResetChallenges`), and — like the `users/{uid}` write it shares a
  transaction with — go through `firestoreDb()` (the migration-aware
  Firestore accessor), not `admin.firestore()` like password reset's
  challenges use; password reset intentionally stays on the default
  database since it isn't identity-doc-related, but this feature's two
  writes must be transactionally consistent, which requires one Firestore
  instance for both.
- **`CompleteProfileScreen` redesign.** Restyled per a reference mockup:
  a `welcomeBackCardDecoration`-based gradient badge above the title,
  `AppTextField`s with leading icons for name/phone, and a new
  screen-local `_GradientContinueButton` (green->orange, reusing
  `welcomeBackCardDecoration` for the fill) replacing `SolidButton` — kept
  local to this one screen since `SolidButton` itself has no gradient
  variant and nothing else needed one. The phone field gained a fixed,
  non-editable "+91" prefix (`InputDecoration.prefixText`) and a 10-digit
  formatter/validator (`^[6-9]\d{9}$`, matching `settings_screen.dart`'s
  existing convention) — the stored `phone` value is still the bare ten
  digits; the prefix is presentation-only, not a schema change. The DOB row
  changed from a bare `ListTile` to a read-only `AppTextField` (tap opens
  the same date picker) so it matches the other fields visually. Explicitly
  out of scope, per direct instruction: no Google/Apple sign-in buttons —
  the reference mockup's social buttons were a visual reference only.
- **Splash screen removed.** `AppSplashScreen` (the branded full-bleed
  image splash used as a loading placeholder in `app_bootstrap.dart` and
  `app_entry.dart`) was deleted; every site that showed it now shows the
  existing `AppLoadingIndicator` instead — no other screen was left showing
  a "unique" branded loader, per the "plain loader" request. The file it
  lived in (`widgets/app_splash_screen.dart`) was renamed to
  `widgets/app_logo_text.dart` since it also held `AppLogoText` (the
  animated shader-gradient "ChurchTree" text used in `ChurchPickerScreen`'s
  "Welcome Home" header), which was kept — only the image-splash class was
  removed as a feature, not the file's other widget.

### Addendum (sign-up reordered: profile step now comes before email/password,
behind an explicit Sign In / Sign Up choice)

Direct follow-up feedback: `CompleteProfileScreen` should only ever appear
during sign-up (not as part of an ambiguous combined screen), the first
screen after onboarding should be an explicit Sign In / Sign Up choice
rather than a guess, and the Sign Up path specifically should collect
profile info first, then email/password, then email verification.

- **New screens**, all in `screens/entry/`: `auth_choice_screen.dart`
  (`AuthChoiceScreen` — two buttons, Sign In / Sign Up, no guessing; this is
  now the screen `AppEntry` shows for anyone signed out, replacing the old
  combined `CreateAuthAccountScreen`), `sign_in_screen.dart` (`SignInScreen`
  — dedicated email+password sign-in, reached from the choice screen), and
  `create_account_screen.dart` (`CreateAccountScreen` — email+password+
  confirm, the *last* step of sign-up, reached only after the profile step).
- **`CompleteProfileScreen` now serves two call shapes**, both funneling
  through the same form (see `KT Files/features/authentication-and-entry.md`
  for the full description): a new pre-account sign-up shape, taking an
  `onContinue(ProfileDraft)` callback and never touching Firestore (there is
  no `uid` yet — the collected fields are handed forward to
  `CreateAccountScreen` instead), and the original resume shape (`onContinue`
  null, the default) unchanged from before — `AppEntry`'s "identity doc
  missing" branch still uses it exactly as it always did, for the case
  where a Firebase account exists without a completed profile (e.g. an
  interrupted sign-up). `ProfileDraft` (name/phone/dob/gender) is a small
  new class in the same file, carrying the collected fields between the two
  screens without either needing Firestore access.
- **`CreateAccountScreen`** creates the Firebase account and immediately
  calls `UserIdentityRepository.createIdentity` with the carried
  `ProfileDraft` plus the new email — both happen back to back here, so
  (on this path) `AppEntry` never sees a signed-in user with a missing
  identity doc the way the old flow briefly could. On `email-already-in-use`
  it shows an explanatory message and pushes `SignInScreen` pre-filled with
  that email, discarding the draft (there's no account to attach it to).
  `SignInScreen` does the mirror image on `user-not-found`: a message plus a
  link back into the sign-up path (starting at `CompleteProfileScreen`
  again, not at `CreateAccountScreen`, since profile info is still needed).
- **`CreateAuthAccountScreen` is now admin-create-member only.** Every other
  call site that used it (`AppEntry`'s two signed-out branches, and the
  `initialLoginMode: true` logout/delete-account re-entry points in
  `select-church-screen.dart` and `settings_screen.dart`) was rewired to
  `AuthChoiceScreen`/`SignInScreen` directly, leaving `members_screen.dart`
  (`adminCreateMode: true`) as the only remaining caller. Since that mode
  never showed a password field at all (a temporary password is generated
  and emailed instead), the entire self-service half of the widget — the
  `_AuthStep` step machine, `_isLoginMode`/`initialLoginMode` guessing, the
  password/confirm-password fields and their validators, the manual
  login/register toggle — was dead code once nothing constructed it without
  `adminCreateMode: true` anymore, and was deleted rather than left in
  place; the `initialLoginMode` constructor param was removed along with it.
  The class keeps its name (still an accurate description of what it does:
  create a member's Firebase auth account) rather than being renamed, to
  avoid unnecessary churn at its two remaining call sites beyond dropping
  the now-always-true `adminCreateMode: true` argument.
- `login_entry_screen.dart` (`LoginScreen`, a per-church login screen) and
  `auth_entry_screen.dart` (`AuthEntryScreen`) remain pre-existing dead code,
  unrelated to and untouched by this change — same as noted in earlier
  addenda.

### Addendum (real bug: the email-OTP gate was catching people who already
had an account)

Direct feedback: someone who already has an account should never be asked
to verify their email. The previous addendum's `emailVerified` default
(`_bool(data['emailVerified'])`, which reads a missing field as `false`)
got this backwards — it meant every identity doc written before this
feature existed, and every one seeded directly by an admin action
(`MembersRepository.attachFirebaseAuthToMember`, which constructs
`UserIdentity` and calls `.toMap()` without ever mentioning
`emailVerified`), read as unverified and got sent through
`EmailOtpVerificationScreen` on next launch — not just new sign-ups.

Fixed in `models/user_identity_model.dart`:

- The model constructor's default flipped from `emailVerified = false` to
  `emailVerified = true` — so any code path that builds a `UserIdentity`
  without explicitly mentioning the field (like `attachFirebaseAuthToMember`)
  now defaults to already-verified, matching how every other admin-seeded
  identity is treated.
- `UserIdentity.fromFirestore` now reads a **missing** `emailVerified`
  field as `true`, and only respects an **explicit** `false`
  (`data['emailVerified'] == null ? true : _bool(data['emailVerified'])`).
  A doc written before this feature existed has no such field at all, so it
  now reads as verified instead of unverified.
- `UserIdentityRepository.createIdentity` is unchanged — it still writes
  `emailVerified: false` explicitly, since it's the one place a brand-new
  identity doc is created for someone who hasn't proven their email yet
  (both the fresh `CreateAccountScreen` sign-up path and
  `CompleteProfileScreen`'s resume path funnel through it). That explicit
  `false` is what the whole gate is actually keyed on now — everything else
  defaults to "already verified," and only this one write path opts a
  person into the check.

### Addendum (auth wizard visual cleanup: no gradient buttons, decorative
icons removed, a way back to Sign In from the profile step)

Direct follow-up feedback, all in `screens/entry/`:

- **No gradient buttons anywhere in the app.** `CompleteProfileScreen`'s
  `_GradientContinueButton` (added in the redesign addendum above) was
  deleted; its Continue button is a plain `SolidButton` again, matching
  every other screen in the app. `welcomeBackCardDecoration` itself (the
  gradient decoration helper) is untouched and still used elsewhere for
  non-button decoration (e.g. the Pastor card) — the instruction was about
  buttons specifically, not gradients in general.
- **Decorative icons removed** from several auth screens: the person-icon
  badge above `CompleteProfileScreen`'s title, `ForgotPasswordScreen`'s
  `ChurchLogoAvatar`, `PasswordResetCodeScreen`'s `ChurchLogoAvatar`, and
  `ResetPasswordScreen`'s `Icons.lock_reset_rounded`. `ResetPasswordScreen`'s
  *other* icon (`Icons.link_off_rounded`, shown only in the invalid/expired
  link error state) was left alone — it conveys the actual error, not
  decoration. `ForgotPasswordScreen`/`PasswordResetCodeScreen` still accept
  a `churchLogo` constructor param (still threaded through to
  `ResetPasswordScreen` for whatever future use); only the widgets that
  displayed it were removed, not the plumbing — no other call site needed
  to change.
- **`CompleteProfileScreen` gained a way back to Sign In.** Previously it
  had no exit at all in its pre-account sign-up shape (`onContinue` set) —
  reasonable when it was reached only from `AuthChoiceScreen`, but with
  `SignInScreen`'s own "Need a new account? Register" link also landing
  here, someone who arrived by mistake had no way back. A `TextButton`
  (`auth.register_toggle_login` — the same string `CreateAccountScreen`
  already uses for the same purpose) now pushes `SignInScreen`, shown only
  when `onContinue` is set; the resume shape (`onContinue` null, rendered
  directly by `AppEntry` with no push behind it) still has no such link,
  since there is nothing sensible to "go back" to there and the person is
  already signed in. This does mean `complete_profile_screen.dart` and
  `sign_in_screen.dart` import each other — an existing pattern already
  established between `sign_in_screen.dart` and `create_account_screen.dart`
  in the previous addendum, not a new one; Dart permits the cycle and it
  analyzes clean.

### Addendum (real bug: bouncing between Sign In and Sign Up grew the nav
stack unboundedly)

Direct feedback: switching back and forth between `CompleteProfileScreen`
("Tell us about you") and `SignInScreen` ("Welcome back") was stacking up —
each link used a plain `Navigator.push`, so every toggle added a new route
on top rather than returning to one already on the stack. Enough back-and-
forth left an arbitrarily deep stack, and system back had to be pressed
that many times to actually leave.

Fixed by centralizing every Sign In ↔ Sign Up transition into two functions
in a new `screens/entry/auth_navigation.dart`: `goToSignIn(context,
{initialEmail})` and `goToSignUp(context)`. Both call
`Navigator.popUntil((route) => route.isFirst)` before pushing the target —
collapsing back to `AuthChoiceScreen` (always `route.isFirst` on this
navigator, since it's rendered inline by `AppEntry`, itself always reached
via `pushAndRemoveUntil` whenever the app resolves to "signed out") rather
than growing on top of whatever was already pushed. Every cross-link that
previously built its own `MaterialPageRoute` now calls one of these two
functions instead: `AuthChoiceScreen`'s two buttons, `SignInScreen`'s
"Register" link, `CompleteProfileScreen`'s "Login" link (added in the
previous addendum), and `CreateAccountScreen`'s "Login" link plus its
`email-already-in-use` auto-redirect. The one exception is
`SignInScreen`'s forgot-password link — `ForgotPasswordScreen` sits outside
this particular toggle (there's no "Sign Up" equivalent to bounce back to),
so it stays a plain push.

This incidentally undid the import cycles the previous two addenda noted as
acceptable-but-not-ideal (`complete_profile_screen.dart` ↔
`sign_in_screen.dart`, `sign_in_screen.dart` ↔ `create_account_screen.dart`):
those three screens no longer import each other directly at all, only
`auth_navigation.dart` (which imports all three, to construct them) and, for
`create_account_screen.dart`, `complete_profile_screen.dart` alone (for the
`ProfileDraft` type its constructor takes). The cycle still exists — between
`auth_navigation.dart` and each screen it constructs — but a hub-and-spoke
cycle through one shared navigation file is a clearer, more standard shape
than a mesh of pairwise cycles between the screens themselves.

### Addendum (`CompleteProfileScreen`'s missing back button; both reciprocal
Login/Register links removed in favor of the app-bar back button)

Direct follow-up feedback: `CompleteProfileScreen` had no back button at
all (no `AppBar`), and — separately — the "Already have a Church Tree
account? Login" link added to it, and the "Need a new Church Tree account?
Register" link on `SignInScreen`, should both go away.

- `CompleteProfileScreen` gained a plain transparent `AppBar` (no title —
  the body's own heading already says "Tell us about you") purely for its
  automatic back button. In the sign-up shape it's always pushed directly
  on `AuthChoiceScreen` (`goToSignUp`'s stack-collapsing guarantees this),
  so Flutter shows a working back arrow there; in the resume shape
  (`onContinue` null, rendered inline by `AppEntry` with nothing beneath it
  to pop to) Flutter automatically omits the back arrow rather than showing
  a dead one — no conditional logic needed on this screen's part.
- Its "Already have a Church Tree account? Login" `TextButton` (added two
  addenda ago) was deleted, along with the now-unused `auth_navigation.dart`
  import that only existed for it.
- `SignInScreen`'s "Need a new Church Tree account? Register" `TextButton`
  was likewise deleted (along with its `auth_navigation.dart` import) —
  this screen is always pushed directly on `AuthChoiceScreen` too, so its
  own app-bar back button already does the same job.
- `auth.login_toggle_register` (the now-fully-orphaned "Need a new Church
  Tree account? Register" string) was removed from
  `text_content_defaults.dart`. `auth.register_toggle_login` ("Already have
  a Church Tree account? Login") stays — `CreateAccountScreen` still uses
  it for its own Login link, which was **not** asked to be removed and is
  arguably still earning its place there: unlike `CompleteProfileScreen`
  and `SignInScreen`, `CreateAccountScreen`'s natural back button already
  goes to `CompleteProfileScreen` (the previous step of sign-up), not to
  Sign In, so its explicit Login link remains the only way to reach Sign In
  directly from that screen without going back through the profile step.

### Addendum (logout/delete-account now land on `AuthChoiceScreen`, not
`SignInScreen`)

Direct follow-up feedback: logging out should land back on the Sign
In/Sign Up choice, not assume "sign back in" is what's wanted next — someone
logging out (e.g. to hand the device to someone else, or switch accounts)
may just as well want to register a different account.

The three `pushAndRemoveUntil` call sites that previously targeted
`SignInScreen` directly (a leftover from the addendum before last, which
introduced `SignInScreen` and rewired these without reconsidering which
screen was actually right for "signed all the way out") now target
`AuthChoiceScreen` instead: `SelectChurchScreen._handleLogout`,
`settings_screen.dart`'s Logout tile, and its `_DeleteAccountSection`
success path. No other behavior changed — same `pushAndRemoveUntil`,
same zero-duration transition on the two logout sites.

### Addendum (`EmailOtpVerificationScreen` back button; last reciprocal
Login link removed; OTP delivery diagnosed as a deployment gap, not a bug)

Three items from one bug report:

- **`EmailOtpVerificationScreen` had no back button at all.** Unlike
  `CompleteProfileScreen`/`SignInScreen` (whose back buttons are the
  `AppBar`'s automatic one, since both are always pushed on top of
  `AuthChoiceScreen`), this screen is rendered inline by `AppEntry` and
  never pushed — there is no previous route to pop to, and "going back" a
  step doesn't make sense once the account and identity doc already exist.
  So its new `leading: BackButton` doesn't pop; it signs out
  (`ref.read(firebaseAuthProvider).signOut()`) and
  `pushAndRemoveUntil`s to `AuthChoiceScreen`, invalidating
  `userIdentityProvider` on the way. The identity doc is left exactly as it
  is (still `emailVerified: false`); signing back in with the same
  credentials lands right back on this screen, so nothing is lost.
- **`CreateAccountScreen`'s "Already have a Church Tree account? Login"
  link was removed** — the last of the three reciprocal Login/Register
  links this and the previous addendum together removed piece by piece.
  Reasoning for keeping it in the previous addendum (its back button goes
  to `CompleteProfileScreen`, not `SignInScreen`) no longer held once asked
  directly to remove it — the automatic `email-already-in-use` redirect to
  `SignInScreen` (not a button, error-recovery) still covers the one case
  where landing on Sign In from this screen is actually necessary.
  `auth.register_toggle_login` is now fully orphaned and was removed from
  `text_content_defaults.dart`, alongside `auth.login_toggle_register` in
  the previous addendum — no more toggle-link strings exist anywhere.
- **"No OTP email arrives" and "resend stuck at 60s" are the same root
  cause, and it isn't a code bug**: `firebase functions:list` on the
  project confirms `requestSignupEmailVerificationCode` and
  `verifySignupEmailVerificationCode` (added several addenda ago) were
  never deployed. Every call to `requestSignupEmailVerificationCode`
  therefore fails before reaching SMTP, which explains both symptoms at
  once — no email is ever actually attempted, and
  `EmailOtpVerificationScreen._startResendCountdown` only runs after a
  *successful* send, so the countdown never starts and "Resend code in
  60s" never ticks down. Deploying the two functions (with the SMTP
  secrets already configured for password reset, since both feature sets
  share the same `smtpUser`/`smtpPass`/transporter) is required and
  sufficient to fix both — no client-side change is needed. Left
  undeployed pending explicit go-ahead, per this project's standing
  never-deploy-without-asking rule.

**Both functions were deployed** in a follow-up (`firebase deploy --only
functions:requestSignupEmailVerificationCode,functions:verifySignupEmailVerificationCode`),
confirmed live via `firebase functions:list`.

### Addendum (`emailVerified` enforced in `firestore.rules`, not just
`AppEntry`'s routing)

Direct follow-up: "after successful authentication via OTP only we are
taking the authentication into account" — i.e. an unverified account
shouldn't count as authenticated anywhere, not just in what the app's own
screens let you navigate to. Auditing `firestore.rules` found it never
checked `emailVerified` at all — every rule gated only on `request.auth !=
null` (`isSignedIn()`). `AppEntry`'s client-side routing already correctly
blocked *navigation* until verified, but nothing stopped a direct
Firestore SDK/API call (bypassing the app's screens entirely) from an
unverified account reading or writing anything gated by plain
`isSignedIn()` — church public content, `globalFeeds` (including posting
to it), `globalPrayerRequests`, `globalFeedback`, a self-service
`members/{docId}` create, etc.

Fixed with one new helper, `hasVerifiedEmail()`, deliberately **not**
folded into `isSignedIn()` itself:

```
function hasVerifiedEmail() {
  return isSignedIn() &&
    (!exists(/databases/$(database)/documents/users/$(request.auth.uid)) ||
     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.emailVerified != false);
}
```

Missing entirely (no doc yet, or a doc predating this field) reads as
verified — same semantics as the client-side model fix from several
addenda ago (missing ≠ false). `isApprovedMember`, `isChurchAdmin` and
`isSuperAdmin` now call this instead of `isSignedIn()` directly, which
transitively covers every collection already gated through them (`feeds`,
`prayer_requests`, `families`, `groups`, `youth_circles`, `learning_results`,
`isChurchStaff`-gated admin/financial data, etc. — no changes needed
there). The remaining bare `isSignedIn()` reads that weren't funneled
through those three — `events`, `pastor`, `about`, `articles`,
`home_sections`, `for_you_section`, `live_church`, `footerSupport` (+
`contactItems`/`socialItems`), `learning_config`, church-scoped
`learning_modules`, `bibleRandomSwipeVerses`, `globalFeeds` (read +
create), `globalPrayerRequests` (read), `globalFeedback` (create), global
`learning_modules` (read), and `superAdmins`' self-read — were switched to
`hasVerifiedEmail()` directly, plus the `members/{docId}` self-create
branch (the actual request-access write, previously gated by `isSelf`
alone).

**Deliberately left untouched**: `users/{uid}`'s own `isSelf`-based
read/create/update/delete rule, and its subcollections
(`readingPlans`/`devices`/`favorites`/`learning_progress`). This is the one
place that *must* stay reachable regardless of `emailVerified` — the app
reads this exact doc to learn its own `emailVerified` value in the first
place (`AppEntry`'s `userIdentityProvider` stream), and
`UserIdentityRepository.createIdentity` has to be able to create it with
`emailVerified: false` before verification has happened at all. Folding
the check into `isSignedIn()` itself (the more sweeping-looking option)
would have broken exactly this — the OTP screen would never be able to
observe its own gate flipping to true.

Deployed via `firebase deploy --only firestore:rules` (updates both the
`(default)` and `migrationv1` database rule sets, per `firebase.json`) —
confirmed clean deploy, no rule-compile errors.

### Addendum (real bug found immediately after the above deploy: legacy
accounts got PERMISSION_DENIED on everything)

Deploying `hasVerifiedEmail()` broke real usage right away — device logs
showed `PERMISSION_DENIED` on `churches/{cid}/config/app` and
`churches/{cid}/members` for an existing account. Cause:
`get(...).data.emailVerified != false` dot-accesses a map key that may not
exist (the exact grandfathered case the function exists to handle — a
`users/{uid}` doc that predates this field). Firestore Rules throws an
evaluation error on a missing-key dot-access rather than treating it as
`null`/`undefined`, and a rule that errors evaluates the whole `allow`
expression to `false` — so every grandfathered account (any real account
that existed before this feature, which in practice was every admin and
approved member in the log's session) failed `hasVerifiedEmail()` and lost
access to everything gated through it, immediately.

Fixed by switching to the safe map-access form:
`.data.get('emailVerified', true) != false` instead of
`.data.emailVerified != false` — `Map.get(key, default)` returns the
default instead of throwing when the key is absent, so a doc predating the
field now actually reads as verified rather than crashing to denied.
Redeployed via the same `firebase deploy --only firestore:rules`; this is
the general gotcha to remember for any future rule that reads an optional
field — dot-access assumes the field exists, `.get(key, default)` doesn't.

### Addendum (`SelectChurchScreen` becomes a two-tab shell: Home +
Churches, church-badge app-bar action removed)

Direct follow-up feedback, referencing a screenshot of `SelectChurchScreen`
as it stood (feed body, a church-icon action top-right that pushed
`ChurchPickerScreen`, plus super-admin/logout icons): redesign so "Home"
and "Churches" are tabs, remove the top-right church badge, and tapping
the new "Churches" tab shows the same content the badge used to push.

- `SelectChurchScreen` changed from `ConsumerWidget` to
  `ConsumerStatefulWidget` (holding `_selectedIndex`) and gained a bottom
  `AppBottomTabBar` — the exact same shared widget `ChurchTabScreen` uses
  (`widgets/app_bottom_tab_bar.dart`), not a new one — with two items,
  "Home" (`Icons.home_outlined`/`Icons.home_rounded`, reusing the
  `church_tab.home` string already used for the same concept in
  `ChurchTabScreen`) and "Churches" (`Icons.church_outlined`/`Icons.church`,
  new `select_church.churches_tab` string). The body is
  `[GlobalFeedListView(), ChurchPickerScreen()][_selectedIndex]` — the same
  simple "swap the body widget, no `IndexedStack`" pattern `ChurchTabScreen`
  already uses for its own tabs (switching tabs and back does reset each
  tab's ephemeral UI state, e.g. `ChurchPickerScreen`'s section
  expand/collapse — consistent with how switching away from and back to
  Community already behaves there).
- The top-right `Icons.church_outlined` `IconButton` (tooltip
  `church.picker_action`, pushed `ChurchPickerScreen`) was removed entirely
  — the "Churches" tab replaces it as the way in. `church.picker_action`
  ("Choose a church") became fully orphaned and was removed from
  `text_content_defaults.dart`. The super-admin and logout `IconButton`s
  stay in the single shared `AppBar`, visible across both tabs.
- `ChurchPickerScreen` itself lost its own `Scaffold`/`AppBar`
  (`extendBodyBehindAppBar: true`, transparent bar) — it's now purely a
  body widget (`LinearScreenBackground` → `SafeArea` → the existing
  "Welcome Home" content, unchanged internally: `_handleContinue`,
  `_showChurchDetailsSheet`, `_buildChurchSections`, the your-churches/
  other-churches section cards, all untouched). It was never pushed from
  anywhere else in the app (confirmed via search — the removed app-bar
  action was its only caller), so this is a pure absorption, not a
  parallel code path: there is no longer any route where
  `ChurchPickerScreen` has its own back button, because it's never a
  pushed route at all anymore.

### Addendum (`CreateChurchScreen` polish: phone validation, church-email
label, "Register your church" → "Register"; real Storage-upload bug fixed
for public registration)

Direct follow-up feedback plus a pasted `StorageException`
(`PERMISSION_DENIED`, 403) hit while testing public church registration:

- **Phone validation added.** Neither the church contact field nor the
  admin phone field validated format before — only non-empty. Both now use
  the same `^[6-9]\d{9}$` 10-digit Indian mobile pattern
  `CompleteProfileScreen` established for the signup profile step
  (`auth.phone_invalid` message, digits-only `inputFormatters`,
  `maxLength: 10`), checked in both `_validateStep` (per-step "Continue")
  and `_validate` (final submit gate) — this screen validates both ways
  depending on where the user is in the wizard.
- **Church email field relabelled** `super_admin.email_label`: 'Email' ->
  'Church email' — this screen has two email fields (the church's own and
  the admin's), and "Email" alone was ambiguous next to "Admin Email".
- **"Register your church" → "Register"** for this screen's own app-bar
  title and submit button specifically — but *not* globally: the exact
  string `church.register_your_church` is also the badge text on
  `ChurchPickerScreen`'s "invite a friend to register their church" link
  (`select-church-screen.dart`), where the longer phrase is still the
  right copy. Reusing that key for both would have changed the badge too,
  so this screen's two spots were switched to a new key,
  `super_admin.register_action` = 'Register', instead.
- **Real bug: public registration's logo/pastor-photo upload always
  403'd.** `SuperAdminChurchService.createChurch` uploads both images to
  Storage *before* writing any Firestore doc for the church (`_uploadChurchLogo`/
  `_uploadPastorPhoto` run, then the batch of Firestore writes). `storage.rules`
  gated both paths on `isChurchStaff(churchId)`
  (`isChurchAdmin(churchId) || isSuperAdmin()`). For a super-admin-created
  church this happened to work anyway, because `isSuperAdmin()` checks a
  completely separate, pre-existing `superAdmins/{email}` doc — it never
  depended on the new church's own (not-yet-written) config doc. But for
  **public self-registration**, the registrant is neither a super admin
  nor (yet) listed in a `config/app.admins` that doesn't exist yet —
  `isChurchStaff` could never be true at upload time, so every public
  registration's image upload failed with `PERMISSION_DENIED` before this
  fix, unconditionally. Fixed with two new Storage-rules functions:
  `hasVerifiedEmail()` (a direct port of `firestore.rules`' function of the
  same name, including the same `.data.get('emailVerified', true) != false`
  safe-access form — not `.data.emailVerified`, for the identical
  dot-access-throws-on-missing-key reason documented in the addendum right
  above this one) and `isUnclaimedChurch(churchId)`
  (`!firestore.exists(churches/{churchId})`). Both
  `churches/{churchId}/logo` and `churches/{churchId}/pastorPhotos/{fileName}`
  now `allow write: if isChurchStaff(churchId) || (hasVerifiedEmail() &&
  isUnclaimedChurch(churchId))` — existing staff can always update either
  (edit mode), and anyone verified can write them for a churchId that
  doesn't have a church doc yet (true for both registration modes during
  the brief upload-then-write window, and remains true indefinitely for an
  abandoned/never-completed registration — accepted as harmless Storage
  clutter, not a security exposure, since the matching Firestore write
  still requires `churchExists(churchId)` to be false via the service's own
  `duplicate-id` check, so this can never be used to hijack an
  already-registered church).
- **Known caveat, not fixed here**: `storage.rules`' Firestore cross-checks
  (`isChurchAdmin`, `isSuperAdmin`, and the two new functions above) all
  hardcode `/databases/(default)/documents/...` — Storage rules have no
  equivalent of Firestore rules' `$(database)` variable, so they can only
  ever look at the `(default)` database. If a test session is pointed at
  `migrationv1` (`FIRESTORE_DATABASE_ID` override — see `firestoreDb.ts`
  and `firestore_provider.dart`), every Storage-rule Firestore lookup is
  silently checking the wrong database's copy of `churches`/`users`/
  `superAdmins`, which would misfire independently of the fix above. Out of
  scope for this pass; flagging it since it's the same class of bug and
  could resurface identically if hit during `migrationv1` testing.

### Addendum (two more real, pre-existing bugs found chasing the same
`PERMISSION_DENIED` report after the previous two fixes): `isApprovedMember`
checked a collection that no longer exists, and the request-access
auto-approve check could never succeed for the requester it's supposed to
help

The same device log (`churches/{cid}/config/app` and `churches/{cid}/members`
both `PERMISSION_DENIED`) persisted after the `hasVerifiedEmail()` dot-access
fix and the Storage-rules fix, on a different account/path than either of
those addressed. Root causes this time were both pre-existing — neither
introduced by this session's `hasVerifiedEmail()` work — just newly exposed
by testing this flow closely:

- **`isApprovedMember(churchId)` checked
  `churches/{churchId}/users/{uid}`** — the exact collection name the D1
  rename (§5, this doc) retired in favor of
  `churches/{churchId}/members/{uid}`. The top-of-file "Authority model"
  comment still said "member: approved == true on
  churches/{churchId}/users/{uid}" too — both the code and its own
  documentation were stale in the same way, which is presumably why nobody
  had caught it: every approved *member* (as opposed to admin or super
  admin) has had `isApprovedMember` silently return `false` since the D1
  rename, for anything gated by it — `config/app` read, `families`,
  `groups`, `feeds` create, `prayer_requests`, `learning_results`, etc.
  Fixed by pointing both the `exists()` and `get()` calls at `members/{uid}`
  instead of `users/{uid}`, and correcting the stale comment.
- **`RequestChurchAccessScreen`/`LoginRequestScreen`'s "am I the sole
  admin, are there zero members yet" auto-approve check could throw
  `PERMISSION_DENIED` for the *only* callers who actually hit it in
  practice.** The check reads `churches/{cid}/members` (an unfiltered
  `.limit(1)` query) and `churches/{cid}/config/app` before the caller has
  any membership row at all. Under `firestore.rules`, both reads are only
  provably safe for a caller who is already `isChurchStaff` (a
  doc-independent condition, so Firestore can allow the query without
  knowing which document comes back) — which, for this exact check, is
  precisely the founding-admin case it exists to detect (their email is in
  `config/app.admins`, so `isChurchAdmin`'s own internal `get()` — rules
  internals bypass the read-permission chain — already resolves `true`
  independent of this client-side read). For every *other* requester (the
  overwhelmingly common case: an ordinary person asking to join a church
  they don't administer), neither condition holds, so both reads threw,
  and — since neither call was wrapped in its own `try`/`catch` — the
  exception propagated out of the surrounding `if` block and was caught by
  `_submit()`'s **outer** try/catch, which reports it as a failure and
  aborts the whole request. In effect, self-service request-access could
  never complete for anyone except (accidentally) an already-privileged
  caller — the exact opposite of who requests access. Fixed by wrapping
  both reads in their own `try { ... } catch (_) { shouldAutoApprove =
  false; }` in both screens: a normal requester now falls through to the
  ordinary pending-approval path (correct outcome for them anyway) instead
  of the whole submission failing, while the founding-admin case is
  unaffected (its read already succeeds, so the `try` block completes
  normally).

### Addendum (root cause of the persisting `PERMISSION_DENIED` reports,
found by directly reading the actual data instead of guessing from logs
again): `currentChurchIdProvider`'s local-storage fallback trusted a
remembered church id with no approval check — the client-side twin of the
`selectedChurchProvider` bug class already documented twice above

The same two `PERMISSION_DENIED` lines persisted, unchanged, after both
fixes above. Rather than guess a fourth time, used the project's own
`functions/*-firebase-adminsdk-*.json` service account (Admin SDK bypasses
rules entirely) to read the actual `migrationv1` data directly:
`churches/tnbm` and its `config/app` exist and are well-formed (17 real
members, 4 admins); the test account's own `members/{uid}` doc exists with
**`approved: false`** — i.e. the self-service request-access flow had
already succeeded (write confirmed in Firestore) and correctly left them
pending. The `PERMISSION_DENIED` reads were therefore not a rules bug at
all *for that account* — a pending, unapproved member correctly cannot
read `config/app` or list `members`, by design.

The real question became: why would the client keep *attempting* those
reads for a church the signed-in account is only pending on, when
`AppEntry`'s own routing (`_resolvableChurchId`, `myMembershipsProvider`)
is careful to never resolve a church id that isn't in the approved set?
Answer: `currentChurchIdProvider` — watched by `appConfigProvider`, and
therefore by `textContentProvider`, and therefore by every single
`context.t()`/`ref.t()` call in the app, so it runs continuously
regardless of which screen is showing — has two paths: `selectedChurchProvider`
(trustworthy; only ever set for an approved membership) and, when that's
null, a **fallback straight to `ChurchLocalStorage`'s raw saved value**,
with no approval check at all. Nothing clears that local value except an
explicit logout/delete-account (`ChurchLocalStorage().clearChurch()`) —
switching accounts by any other means (e.g. signing up a new account while
a previous session's church was still saved on the same device) leaves it
stale, and the fallback blindly trusted it. This is the exact same mistake
as the `selectedChurchProvider` bug documented in the "found in a second,
live place" addendum above — a locally-cached church reference being
trusted without revalidating against current approval — just in a
different provider, and specifically responsible for making it a
*continuous* failure (via `appConfigProvider`'s live stream) rather than a
one-off.

Fixed by cross-checking the local-storage fallback against
`myMembershipsProvider` (the same collectionGroup query `AppEntry` already
trusts as authoritative) before returning it — approved for that church id
only if a matching, approved membership actually exists; `null` otherwise
(callers already treat `null` as "nothing resolvable," the same as before
local storage had anything saved). This does add one
`myMembershipsProvider.future` await to the fallback path specifically —
not the common case, since a properly-entered user always resolves via
`selectedChurchProvider` first and never reaches the fallback at all.

### Addendum (the real, bigger bug: church *creation itself* was broken for
any non-super-admin — the Storage fix a few addenda back only covered half
of it)

Another `PERMISSION_DENIED` report, this time with a genuine write failure
attached: `Write failed at churches/{churchId}/groups/administration`,
for a brand-new church ("Yesu Thottam Prayer House") rather than the
already-established "tnbm" the previous three addenda were chasing. Traced
via `SuperAdminChurchService.createChurch()`: it uploads the logo/pastor
photo (Storage, already fixed), then writes the church doc, `config/app`,
`about`, `bibleRandomSwipeVerses`, `footerSupport` (+`contactItems`),
`pastor`, all 7 seeded `groups/{id}` docs, the founding admin's own
`groups/administration/groupMembers/{uid}` row, and every `home_sections`/
`for_you_section` doc — **all in one atomic `WriteBatch`**.

Firestore evaluates every write in a batch against the database state
*before* the batch applies — not against what earlier writes in the same
batch are about to create. So when the `groups/administration` write (and
every other write in that batch) is checked against
`isChurchStaff(churchId)`, `isChurchAdmin(churchId)` calls
`get(churches/{churchId}/config/app).data.admins` — but `config/app` is
*itself* being created in this exact batch, so at evaluation time it
doesn't exist yet, and `isChurchAdmin` fails. For a super-admin-created
church this went unnoticed because `isSuperAdmin()` checks a completely
separate, already-existing `superAdmins/{email}` doc — unaffected by
anything this batch is doing. But for **any non-super-admin** creating a
church — which is the entire point of public self-registration — neither
half of `isChurchStaff` could ever be true during this batch, for *any* of
its dozen-plus writes. Worse: the top-level `churches/{churchId}` document
itself had `allow create: if isSuperAdmin();` with no other path at
all — meaning a public registrant's church-creation batch was doomed
before it even got to `groups/administration`; that path just happened to
be the collection Firestore's client SDK surfaced in the log first.

In other words: **public self-registration of a new church could never
have worked**, end to end, at the security-rules layer, independent of
every fix in the addenda above — the earlier Storage-rules fix
(`isUnclaimedChurch` for the logo/pastor-photo uploads) fixed the half of
this bug that happens *before* the batch, but the batch itself was equally
broken and nobody had reached it yet in a way that produced a report,
until now.

Fixed with the Firestore-rules equivalent of the same `isUnclaimedChurch`
concept already used in `storage.rules`:

```
function isUnclaimedChurch(churchId) {
  return !exists(/databases/$(database)/documents/churches/$(churchId));
}
function canBootstrapChurch(churchId) {
  return hasVerifiedEmail() && isUnclaimedChurch(churchId);
}
```

Applied as `isChurchStaff(churchId) || canBootstrapChurch(churchId)` to
every write rule `createChurch()`'s batch actually touches: `config`,
`about`, `pastor`, `bibleRandomSwipeVerses`, `footerSupport` (+
`contactItems`/`socialItems`), `groups` (+ `groupMembers`),
`home_sections`, `for_you_section`. The window closes permanently the
instant any `churches/{churchId}` doc first exists — so this can never be
used against an already-created church, only during the one atomic batch
that brings a brand-new one into existence. Left untouched:
`learning_config`, `learning_modules`, `announcements`, `events`,
`articles`, `live_church`, `families`, `youth_circles`,
`faith_reflections`, `faith_engagement`, `equipments`,
`learning_results`, `feeds`, `prayer_requests`, `financial_transactions`,
`dashboard_metrics`, `notification_requests` — none of these are written
during church creation, so none needed the bootstrap allowance; broadening
it to collections `createChurch()` never touches would only have widened
the exposure window for no reason.

The top-level `churches/{churchId}` document's own `create` rule needed a
different, more targeted fix (there's no "unclaimed" concept for a
`create` — the document by definition doesn't exist yet): a verified user
may now create one for **themselves only**, and only in the exact shape
`createChurch()`'s public-registration path actually produces —
`request.resource.data.registrationSource == 'public'`,
`registeredByUid == request.auth.uid`, `enabled == false`. They cannot
create an already-enabled church, attribute a new church to someone else's
uid, or (via `update`/`delete`, both unchanged and still `isChurchStaff`/
`isSuperAdmin`-only) touch an existing one.

Confirmed fixed by re-reading the actual data after redeploying (same
service-account diagnostic approach as the previous addendum): the church
that had logged the write failure now exists correctly, fully seeded, with
real (not test) data.

### Addendum (the actual root cause of this entire multi-turn debugging
saga: `firebase deploy --only firestore:rules` was silently a no-op for
this project this whole time — every fix above was correct and simply
never went live until now)

The same `PERMISSION_DENIED` symptoms kept recurring after every fix in
the four addenda above, on a fresh, genuinely-new church
("the_christ_missions_assembly"). Rather than guess again, granted the
account being used for testing (`ephrimdaniel17@outlook.com`) proper
`superAdmins` status directly via the Admin SDK (it had never actually
been added — a separate, real setup gap, now fixed), then re-verified
every fix **using the client SDK signed in as that account**, which
respects rules the way the app does (unlike every earlier "confirmation"
in this doc, which used the Admin SDK and therefore bypassed rules
entirely without anyone — including this doc — noticing that the
diagnostic couldn't actually prove the rules worked).

The client-respecting re-test then showed the *newest* fix
(`canBootstrapChurch`/`isUnclaimedChurch`, the previous addendum) still
failing even for the properly-configured super admin's own separate
church-creation attempt. Bisecting that (with the local Firestore emulator
— required installing a JDK, since Cloud Firestore's emulator is
JVM-based and none was present) proved the **rule logic itself was
correct**: an isolated `@firebase/rules-unit-testing` run against the
exact same `firestore.rules` content, simulating a genuinely non-staff
user's full registration batch, succeeded cleanly in the emulator. So the
deployed rule and the working rule had diverged — meaning the deploy
itself was suspect.

Cross-checking the Firebase Rules API directly
(`GET .../projects/{project}/releases`) confirmed it: the `migrationv1`
release's `updateTime` hadn't moved in **hours**, across half a dozen
`firebase deploy --only firestore:rules` runs in this session that each
printed "Deploy complete!" with no error. Diffing the actually-released
ruleset content against the local file confirmed it was missing
*everything* from today — not just the bootstrap fix, but the
`hasVerifiedEmail()` dot-access fix and the `isApprovedMember` `/members/`
path fix from the addenda before it. None of those fixes had ever
actually reached either database via that command. (The `hasVerifiedEmail`
"fix" appearing to work in the second addendum's re-test was a red
herring — that re-test used the newly-super-admin'd account, so
`isSuperAdmin()` alone — logic untouched since before this session —
explained every success, independent of whether any of the actual edits
were live.)

A `--debug` deploy run made the bug visible: `--only firestore:rules`
only ever performed the `firestore.googleapis.com` "ensure API enabled"
check and nothing else — no ruleset upload, no release call, for either
database — while `--only firestore` (no `:rules` suffix, deploying the
whole firestore target: rules *and* indexes together) correctly compiled,
uploaded, and released the ruleset to **both** `cloud.firestore/(default)`
and `cloud.firestore/migrationv1`, with the release `updateTime` finally
matching the current time. The `:rules` sub-filter appears to be broken
specifically for this project's array-form multi-database `firestore`
config in `firebase.json` (two entries, `(default)` and `migrationv1`) —
untested whether this reproduces for a single-database config, but
irrelevant to this project either way.

**Operationally, going forward: always deploy Firestore rules changes for
this project with `firebase deploy --only firestore`, never `--only
firestore:rules`.** The latter appears to succeed and reports "Deploy
complete!" while doing nothing. Re-verified after switching commands: the
exact same non-staff public-registration batch that failed identically
across four previous fix attempts now succeeds end to end (church doc,
`config/app`, all 7 groups, the founding admin's `groupMembers` row —
confirmed via direct data read afterward), using a disposable throwaway
account created and deleted solely for this verification.

### Addendum (leave-church and switch-church verified end to end with a
real, non-admin account)

Verified both flows against real `migrationv1` data using a disposable
non-staff account and the real client SDK (rules-respecting), plus the
actual deployed `leaveChurch` Cloud Function (confirmed deployed against
`migrationv1` via `functions/.env.flutterlearning-c9f6c`'s
`FIRESTORE_DATABASE_ID=migrationv1` — not simulated).

**Switch church**: the `collectionGroup('members')` query
(`myMembershipsProvider`'s discovery mechanism) correctly found both of
the test account's memberships; `users/{uid}.lastActiveChurchId` updates
(what `UserIdentityRepository.setLastActiveChurchId()` does on every
switch) succeeded for both churches and read back correctly.

**Leave church**: called the real `leaveChurch` callable and confirmed,
via a separate Admin SDK read (bypassing rules, purely to observe server
state), that it deleted `churches/{churchId}/members/{uid}`, the matching
`groupMembers/{uid}` row in every group, and the member's
`learning_progress` subcollection — while leaving the other church's
membership completely untouched. Also confirmed two rules behave exactly
as intended, not bugs: a member cannot delete their own `groupMembers` row
directly (only the Cloud Function, running with admin privileges, can —
by design), and once a member leaves a church they immediately lose read
access to that church's data (a post-leave client read of the group data
correctly gets `PERMISSION_DENIED` rather than "not found").

All test data (2 disposable churches, 1 disposable auth user) was cleaned
up afterward. No code or rules changes were needed for this addendum —
both flows already worked correctly once the deploy-command fix above was
in place.

### Addendum (`displayFieldsUnchanged()` had the same dot-access gotcha as
`hasVerifiedEmail()` — any update to a self-registered pending member,
including a plain approve, was denied)

While testing the real "master admin approves a pending request" flow
against production data, a genuine self-registered member
(`churches/magimayin_Aalayam/members/{uid}`, created via
`AuthRepository.requestAccess()` — the "request church access" self-signup
path) failed `PERMISSION_DENIED` on an `approveMember()` call
(`MembersRepository.approveMember()`, a plain
`.update({approved: true, updatedAt: ...})` that doesn't touch any
`display*` field at all).

Root cause: `requestAccess()`'s create write never sets `displayPhotoUrl`
(confirmed: the field is absent from the real document). `firestore.rules`'s
`displayFieldsUnchanged()` compared it via direct dot-access
(`request.resource.data.displayPhotoUrl == resource.data.displayPhotoUrl`)
— dot-accessing an absent map key throws in Firestore Rules (the exact
same class of bug fixed for `hasVerifiedEmail()` earlier in this doc), so
`displayFieldsUnchanged()` threw and the whole `allow update` expression
denied, for *any* update to *any* self-registered member — approving them,
editing their category, syncing group membership, all of it — regardless
of whether the update actually touched a display field.

Fixed by switching every field access inside `displayFieldsUnchanged()` to
`.data.get('field', null)` (same fix shape as `hasVerifiedEmail()`),
deployed via `firebase deploy --only firestore` (per the deploy-command
addendum above), and confirmed against the exact real document: signed in
as the actual super admin account, ran the exact `approveMember()` update
shape, watched `approved` flip `false → true`, then reverted it back to
`false` so the account's real pending-request state was left exactly as
the user's own manual testing had it.

A related but separate gap was also found and fixed while investigating
this: `displayFieldsUnchanged()` also bakes in `identitySyncedAt`, which
`requestAccess()` stamps with a fresh `serverTimestamp()` on every call —
so if `LoginRequestScreen`'s admin-create-mode path (`adminCreateMode:
true`, `targetUid` set) is ever invoked twice against the same
`targetUid` (a double-tap, or a retry after a dropped response to an
already-successful write), the second call always fails, since a fresh
timestamp can never equal the one already stored. The non-admin
self-registration path already guarded against this (checks
`existingDoc.exists` before writing); the admin-create-mode path did not.
Fixed by adding the same existing-doc guard, scoped to
`adminCreateMode && targetUid != null`
(`lib/church_app/screens/entry/login_request_screen.dart`), showing a
"member already exists" message instead of letting the write hit the
rules and surface a raw `PERMISSION_DENIED`.

### Addendum (a super admin viewing/managing a church they don't
personally administer got member-level UI, not staff-level, despite
having full staff rights per the rules)

While testing member visibility with a real non-admin account (confirmed
via the client SDK: a plain church member can read their own member doc
in full, but a bare `members` collection query — the "All Members" screen's
`getMembersOnce()` — and a direct read of another member's doc are both
correctly denied by `firestore.rules`, exactly as designed), a second,
separate issue surfaced: the client's `isAdminProvider`
(`lib/church_app/providers/authentication/admin_provider.dart`) only
checked the signed-in email against that church's `config/app.admins`
list — it never accounted for super-admin status at all, unlike the
backend's own `isChurchStaff(churchId) = isChurchAdmin(churchId) ||
isSuperAdmin()`. A super admin (the master test account) viewing a church
they aren't personally listed as admin on — e.g. "Magimayin Aalayam",
admins `[ephrim17@gmail.com, arulvivek@gmail.com, abakapaul31@gmail.com]`
— has full staff read/write rights per the deployed rules, but the app
showed them the plain-member UI: no "extended information" section
(financial rating, education, talents, notes), no "church groups" chips,
no edit/approve actions — exactly matching the "only name/gender/DOB, no
church records" symptom reported. (Separately, the specific record being
viewed was also a bare self-registration with no baptism/marriage/
membership-status fields ever filled in — `requestAccess()` doesn't
collect those — which independently makes its "Church Records" section
look sparse; that part is expected, not a bug.)

Fixed both `isAdminProvider` and the churchId-scoped `churchAdminProvider`
to also return `true` when `isSuperAdminProvider` (already existed,
reads `superAdmins/{email}.enabled`) is true, matching the backend's
`isChurchStaff` semantics exactly. `flutter analyze` clean, `flutter
test` 74/74 passing after this change.

### Addendum (reverted the above — a super admin must NOT automatically
get per-church admin UI; confirmed as a real regression against a live
simulator)

The previous addendum's fix was wrong. Checking the active simulator
against `migrationv1` real data (`churches/tnbm/config/app.admins =
[arulvivek@gmail.com, cdurai2012@gmail.com, reginavivek621@gmail.com,
k.jeevad@gmail.com]`, not including the super admin test account),
`ephrimdaniel17@outlook.com` was getting full admin actions on "tnbm" — a
church it has no listed responsibility for — purely because of the
super-admin fallback just added to `isAdminProvider`/`churchAdminProvider`.

The backend's `isChurchStaff(churchId) = isChurchAdmin(churchId) ||
isSuperAdmin()` granting a super admin read/write rights on every church
is intentional (a platform-moderation/emergency-access capability enforced
server-side), but that is not the same thing as the *client* silently
handing every super admin the full per-church admin UI (edit/approve
members, extended info, church groups) for a church they were never
actually added to — "we can't simply put everyone in admin." Reverted
`isAdminProvider` and `churchAdminProvider` back to checking only
`config/app.admins` for that church, with no super-admin fallback.
`flutter analyze` clean, `flutter test` 74/74 passing after the revert.

The original problem this was meant to fix (a super admin's Members-screen
view of a self-registered record looking sparse) was, on reflection,
mostly the OTHER cause identified in that same addendum: a bare
self-registration via `requestAccess()` never collects baptism/marriage/
membership-status/financial/education/talents fields in the first place —
so the "Church Records"/"extended information" sections are correctly
sparse for that record regardless of who's viewing it. If a super admin
genuinely needs to manage a specific church's members, the correct fix is
adding them to that church's `config/app.admins` (or a future dedicated
"super admin acting as this church's staff" mode with an explicit,
visible toggle), not an implicit blanket grant.

### Addendum (new feature: a reduced, any-approved-member-readable member
directory — `churches/{churchId}/memberDirectory/{uid}`)

Separate follow-up ask on the same thread: a non-admin member should be
able to browse a basic roster of fellow members (name, DOB, marital
status, gender) without seeing phone/email/address/baptism/financial/
notes, which must stay staff-only.

Firestore has no field-level security — `members/{docId}`'s `allow read:
if isSelf(docId) || isChurchStaff(churchId)` is genuinely all-or-nothing
per document (confirmed empirically: a real non-admin, non-staff approved
member gets `permission-denied` on a bare `members` collection query AND
on a direct single-doc read of another member — there was no partial-field
leak to explain away). So the only clean way to expose a reduced field set
to everyone is a *separate* document, kept in sync.

Implementation (asked the user to choose between a Cloud Function mirror
vs. client dual-write, and whether to include the profile photo; picked
Cloud Function mirror + include photo):
- New Firestore rule, `churches/{churchId}/memberDirectory/{docId}`:
  `allow read: if isApprovedMember(churchId) || isChurchStaff(churchId);
  allow write: if false;` — write-only via Admin SDK.
- New Cloud Function `mirrorMemberDirectory`
  (`onDocumentWritten` on `churches/{churchId}/members/{memberId}`,
  `database: firestoreDatabaseIdParam` like the other migration-era
  triggers): mirrors `displayName`, `displayPhotoUrl`, `displayDob`,
  `displayGender`, `displayMaritalStatus` into
  `memberDirectory/{memberId}` whenever the source member doc is approved,
  and deletes the mirror when the member is deleted or no longer approved
  (`approved !== true`) — so the roster never shows a departed or still-
  pending person.
- Backfilled all *existing* approved members (52 across 16 churches with
  members, out of 19 total churches in `migrationv1`) via a one-off Admin
  SDK script, since the trigger only fires on *future* writes to
  `members/{uid}`.
- Client: `ChurchMemberDirectoryEntry` model, `memberDirectoryProvider` /
  `MembersRepository.getMemberDirectoryOnce()`, and `MembersScreen` now
  branches entirely on `isAdminProvider` at the top of `build()` — a
  non-admin gets a separate, simpler scaffold (search + flat list, no
  tabs/family-grouping/special-days) sourced from `memberDirectoryProvider`
  instead of attempting `membersProvider` (which would just throw for the
  whole screen, per the paragraph above).

Verified end to end with two disposable non-admin accounts and the real
client SDK: `memberDirectory` collection read succeeds and each entry
contains *only* the 5 mirrored fields (confirmed via exact key-set
comparison) — while the full `members` collection query and a direct read
of another member's full doc are both still denied, exactly as before.
One false alarm during verification: immediately after a fresh Cloud
Functions deploy, a write made within roughly the first ~30–60 seconds
didn't trigger the mirror — this is Eventarc trigger-registration
propagation delay on a brand-new 2nd-gen trigger, not a code bug;
re-touching the same document minutes later mirrored correctly, and the
Admin-SDK backfill (which doesn't depend on the trigger at all) was
unaffected. All test data (1 disposable church, 2 disposable accounts)
cleaned up afterward.
