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
