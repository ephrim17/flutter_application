# Daily Verse AI Card Caching — Implementation Plan

Authored: 2026-09-18.

| Phase | Scope | Status |
|---|---|---|
| Phase 0 | Quota refund + usage logging on the existing on-demand path | **Not started** |
| Phase 1 | Storage rules, GCS lifecycle rule, Firestore TTL policy | **Not started** |
| Phase 2 | `getDailyVerseCards` callable (server-resolved inputs, lock, per-church cap) | **Not started** |
| Phase 3 | Client switch in `verse_share_modal.dart` + Daily Verse call site | **Not started** |
| Phase 4 | `KT Files/` documentation and numbered test flows | **Not started** |

Keep this table current. A stale "not started" on shipped work misleads the
next implementer.

## How to use this document

This is a handover spec. Every decision in §1 is settled — do not re-open one
without asking the owner. §7 ("Critical correctness notes") holds the things
that cause a security bug or a cost blowout if implemented naively; read it
before writing code.

All `file:line` references were verified against the working tree on
2026-09-18. Line numbers drift — the **symbol names are authoritative**.

Repo rules that still apply and are not restated here: `AGENTS.md`
(localization, church scoping, `mounted`/`ref` safety), `CLAUDE.md` (release
verification, docs policy), `KT Files/features/for-you-content.md` (the owner
of AI verse-card behaviour), `KT Files/features/bible-and-favorites.md` (the
reader path).

---

## 1. Decisions

| # | Decision | Chosen |
|---|---|---|
| D1 | Generation trigger | **Lazy on first request** per church/day/language — the first member to open Daily Verse that day triggers generation and every later member reads the stored result. No nightly cron, no hybrid, no scheduler. Owner confirmed 2026-09-18 after explicitly considering and rejecting a scheduled function. |
| D2 | Language | **Only the language actually requested** is generated; each language is its own cache entry. |
| D3 | Cache key | `churchId` + church-day key (Asia/Kolkata) + language. One Firestore doc per church-day holding both languages. |
| D4 | Invalidation | A **content fingerprint** stored on the entry; any mismatch is a miss and regenerates under a new object name. |
| D5 | Verse text source | **Option B — chosen by the owner 2026-09-18.** The client sends `book`, `chapter`, `verse` *and* the rendered `verseText` and display `reference`. The server reads `config/app.dailyVerse` and **rejects the call** (`failed-precondition`) if the client's reference does not match it. The fingerprint (D4) is built from the *server's* config values, never the client's, so a caller cannot move the cache key — steady state stays one batch per church per day and the D8 cap is never reachable by a user. Accepted residual risk: a tampered direct call can still put wrong verse text on the shared card. Rejected Option A (full server-side resolution from the Bible JSON) closed that too, but cost the D18 Tamil-name duplication for no cost saving. |
| D6 | Church name / contact / date label | All resolved **server-side** (church doc + Asia/Kolkata clock) — confirmed by the owner. Near-free: the function already reads `churches/{churchId}` to authorize the caller, and the date is the server clock. Values come out identical to what the client would have sent. |
| D7 | Concurrency | Firestore transaction on the church-day doc; `generating`/`ready`/`failed` state machine; 240s stale-lock takeover. |
| D8 | Quota model | Daily Verse path **does not touch** `users/{uid}/aiUsage`. It gets its own **per-church daily generation cap** (`DAILY_VERSE_CARD_DAILY_CAP`, default `3`). Chosen by the owner over `4`: it
covers both languages plus one regeneration, and caps a church at
₹115.65/day. A church that changes its Daily Verse *and* its name/contact in
the same day, in both languages, will hit the cap and keep serving the
previously-cached card until tomorrow. |
| D9 | Existing refund bug | Fixed in Phase 0: `generateVerseBackgroundImage` refunds the reserved unit when **every** candidate fails. |
| D10 | Storage path | `dailyVerseCards/{churchId}/{dayKey}/{lang}-{style}-{fp}.jpg` at **bucket root**, not under `churches/`. |
| D11 | Storage rules | Read: approved member of that `churchId`, or that church's admin. Write: `if false` (Admin SDK only). |
| D12 | Client transport | Client reads **bytes** from Storage via `ref().getData()`. The callable returns paths, not base64 and not download URLs. |
| D13 | Retention | GCS lifecycle rule deletes `dailyVerseCards/` objects at age **14 days**; Firestore native TTL on the `dailyVerseCards` collection group via `expireAt`. |
| D14 | New surface | **No new Cloud Function and no scheduler** (owner decision, 2026-09-18). The existing `generateVerseBackgroundImage` gains an optional `dailyVerse: {churchId, language}` argument: present → run the lock/cache/upload path below; absent → behave exactly as today. The function performs the Storage upload and the Firestore write itself, before returning, so both stay Admin-SDK-only (D11) and members keep read-only access. |
| D15 | Failure UX | Distinct states: `ready` (show cards), `generating` (friendly "being prepared" + retry), `failed`/cap-exhausted (existing friendly failure text). **Never** silently fall through to an on-demand generation. |
| D16 | Guest / no-church | Out of scope. Daily Verse is never reachable with `isGuestShare: true` (verified §3.5). No global cache bucket. |
| D17 | Bible reader + Favourites | Stay **on-demand and per-user capped**, uncached. Arbitrary user-chosen verses cannot be pre-generated. |
| D18 | Tamil book names on the server | **Dropped** — consequence of D5 Option B. The client already holds the Tamil book names (`bible_catalog.dart`) and sends the rendered display reference, so `functions/src/bibleBooks.ts` is not created and there is no 66-entry table to keep in sync. |
| D19 | Admin force-regenerate | No Studio "regenerate" button in this scope. Changing the Daily Verse reference in Studio changes the fingerprint (D4) and regenerates on the next request, subject to D8's cap. |
| D20 | "Create manually" | **Untouched.** No change of any kind to `VerseShareModal`. |

> **Amendment, 2026-09-18.** D1, D5, D6, D8 and D14 were revised with the owner
> after the first draft. A scheduled/cron generator was explicitly considered
> and rejected; D1's lazy trigger stands. The consequential change is **D14**:
> there is no new `getDailyVerseCards` callable. Sections 4.6, 4.7, 6 (Phase 2)
> and 8 still describe the behaviour as a separate function — read them as
> describing the `dailyVerse`-mode branch *inside*
> `generateVerseBackgroundImage`, whose call sites without that argument must
> keep today's behaviour byte for byte. The decision table above is the
> contract where the two disagree. **D5 resolved to Option B**, which drops
> D18 — ignore §4.7 step 9's server-side verse lookup and the
> `functions/src/bibleBooks.ts` work in §8 and Phase 2; the server validates
> the client's reference against `config/app.dailyVerse` instead. All
> decisions are now settled; nothing in this document is open.
>
> **Redesign, 2026-09-23 — generation moved to Studio.** The owner changed
> who triggers generation. This supersedes D1, D8 and D14's client half:
>
> - **D1 is now admin-triggered, not lazy.** A church admin presses
>   **Generate images** in the Studio Daily Verse editor, below "Change
>   book/chapter/verse". One press generates **both languages** (2 batches,
>   ~₹77). Members never trigger generation at all.
> - **The For You Daily Verse share icon is view-only.** It calls the
>   function in `mode: 'fetch'`, which reads the cache and returns
>   `unavailable` rather than generating. Tapping it can never cost money.
>   The Tamil/English toggle selects which of the two stored sets is shown.
> - **Generation is admin-only, enforced server-side.** `authorize()` returns
>   whether the caller is a church admin, and a `generate` call from a
>   non-admin is rejected with `permission-denied: admin-required`. A member
>   cannot spend the church's cap even by calling the endpoint directly.
> - **When the admin hasn't generated yet**, members get "Today's verse
>   images haven't been created yet" — a message, not a fallback generation.
> - **The manual editor is hidden from the For You Daily Verse share icon**
>   for now, at the owner's request. `VerseShareModal` itself is untouched
>   and still reachable from Favourites; where it re-surfaces for Daily
>   Verse is an open product question.
> - **D8's cap is 4** (both languages, plus one full redo).
> - The Studio editor now also previews the **Tamil** text and reference
>   alongside the English, since members read whichever they toggle to.
>
> The cache mechanics below — fingerprint, transaction lock, stale-lock
> takeover, failure cooldown, Storage layout, rules, retention — are
> unchanged and still accurate.

> **Build status, 2026-09-19.** Phases 0-4 are implemented and deployed
> (function, `firestore.rules`, `storage.rules`, web client). Two items from
> Phase 1 are **NOT done** — both are Google Cloud console / `gcloud` actions
> that cannot be performed from this repo, and neither blocks the feature
> working, only its housekeeping:
>
> 1. **GCS lifecycle rule** — delete objects under prefix `dailyVerseCards/`
>    at age 14 days. Merge into the bucket's existing lifecycle config, do
>    not replace it (§7.6).
> 2. **Firestore TTL policy** — on collection group `dailyVerseCards`, field
>    `expireAt`. The function already writes `expireAt`; without the policy
>    nothing acts on it.
>
> Until both exist, cards and their docs accumulate indefinitely. Storage
> cost is negligible at current volumes, so this is a cleanliness gap rather
> than an urgent one.
>
> Also note `functions/` has **no test runner**, so the lock and cap logic
> carries no automated test. `decideLockOutcome` was extracted as a pure
> function to make that possible if a runner is ever added; until then the
> verification is FORYOU-23 through FORYOU-30, by hand.

> **Amendment, 2026-09-23 — previous-day fallback on the fetch path.**
> Owner's request: "if the images are not shown for today use the image from
> previous day". `fetch` mode (members, For You) no longer returns
> `unavailable` the moment today's entry is missing or fingerprint-stale.
> It now reads the previous `FALLBACK_LOOKBACK_DAYS` (7) church-day docs by
> id in a single `getAll`, newest first, and serves the first entry for the
> requested language that is `ready` with non-empty `cards`.
>
> **Do not "simplify" this back into a query.** The obvious expression of
> "most recent first" is
> `orderBy(documentId(), "desc").startAfter(today).limit(7)`, and that is how
> it was first written. Firestore rejects it: descending `__name__` ordering
> needs a composite index this project does not have, so the call fails with
> `FAILED_PRECONDITION` — which surfaces to the member as the very
> "not created yet" card the fallback exists to prevent, with nothing in the
> function logs to say why. Caught on the emulator, 2026-09-23. Point reads
> need no index, are bounded at 7, and run only on a miss. The day keys come
> from the exported pure `previousDayKeys`.
>
> - **Fingerprint is not checked on a fallback entry.** An earlier day's
>   fingerprint hashes that day's `dayKey` and verse, so it can never match
>   today's; serving it anyway is the point. D4's invalidation still governs
>   *today's* entry — a stale-fingerprint entry for today is skipped, and the
>   scan starts strictly before today, so the church's previous day is shown
>   rather than today's old-verse cards.
> - **Consequence to be aware of:** the fallback image carries the *earlier*
>   day's verse text and date label. The For You card shows images only (no
>   verse text beside them), so nothing contradicts on screen, but a member
>   can be looking at yesterday's verse. Product may later want a "from
>   <date>" hint; the callable already returns `fromDayKey` for that.
> - **Costs nothing extra on a normal day**: the lookback query runs only on
>   a miss, and 7 is well inside D13's 14-day retention, so every path it
>   returns still exists in Storage. Storage rules already bind on
>   `{churchId}/{dayKey}`, so an earlier day reads fine for members.
> - **Generation is untouched.** `generate` mode never falls back — an admin
>   pressing Generate images always works against today's entry.
>
> Code: `findFallbackCards` in `functions/src/dailyVerseCache.ts`, plumbed
> out through `handleDailyVerse` in `functions/src/verseImage.ts`.

> **Amendment, 2026-09-23 — cards are served by download URL, superseding
> D12.** D12 had the client read card bytes with
> `FirebaseStorage.ref(path).getData()`, so every read was evaluated against
> `storage.rules`. In production that read returned
> `403 User does not have permission to access this object` for an approved
> member of the owning church, reproduced three ways (the owner's device, a
> Maestro run, and a direct authenticated fetch outside the app). The rule was
> live and the member satisfied it on paper — `approved: true`, and
> `users/{uid}` carries no `emailVerified` so `hasVerifiedEmail()` defaults
> true. The deny was never explained; `dailyVerseCards` is the only
> member-facing *read* rule in the file that depends on cross-service
> `firestore.*` lookups, every other one being `isSignedIn()` or `true`, which
> made a failing cross-service lookup the leading suspect. It was not proven:
> reading the project IAM policy and the Rules `:test` API both need
> permissions the Admin SDK key does not hold.
>
> **The fix removes the dependency instead of diagnosing it**, at the owner's
> call, by doing what every other image upload in this app already does —
> feeds, church logos, pastor photos, learning modules all store a
> `getDownloadURL()` result in Firestore and load it straight from the URL:
>
> - `getOrCreateDailyVerseCards` mints a `firebaseStorageDownloadTokens` value
>   when it uploads each card and stores the tokenised URL on the cache entry
>   (`CachedCard.url`). The Admin SDK has no `getDownloadURL()`, so the token
>   is generated with `randomUUID()` and written as object metadata — the same
>   thing `getDownloadURL()` does underneath.
> - `ensureCardUrls` backfills `url` for entries written before this change,
>   reusing the object's existing token when it has one so URLs never rotate
>   out from under a client, and persisting the result so the next reader
>   skips the metadata round trip. This covers the earlier days the fallback
>   serves, not just today's.
> - `fetchDailyVerseCards` fetches the URL through `DefaultCacheManager` and
>   keeps the path-based `getData()` read as a fallback for any card without a
>   URL.
>
> **Security note.** A tokenised download URL is unguessable but
> unauthenticated: anyone holding the link can fetch the image, so church
> scoping on these objects is now by obscurity rather than by rule. That is
> already the accepted pattern for feed images in this app, and a Daily Verse
> card is a devotional image carrying only the church's own name and public
> prayer number. The `storage.rules` block stays as a backstop for the
> path-read fallback — D11's "write: if false" is unchanged, and nothing about
> generation or the cache mechanics moves.
>
> Verified on the Android emulator, 2026-09-23: the For You card renders
> today's Tamil set (23 September 2026, Jonah 2:9) from the URL path, where
> the same build minutes earlier showed "not created yet".

> **Amendment, 2026-09-23 — cards are cached on device.** A card was being
> downloaded from Storage on every visit to For You, about 3 MB per view per
> member, because `dailyVerseCardsProvider` is `autoDispose` and re-runs each
> time the tab is opened. Card bytes now come from `DefaultCacheManager`, the
> same `flutter_cache_manager` store `cached_network_image` uses behind
> `ShimmerImage`, so a card is pulled from Storage once and served from disk
> on every later view, across app restarts.
>
> No invalidation is needed and none should be added: a card URL carries the
> day key *and* the content fingerprint, so a new day, a changed verse or a
> regenerated card is a different URL and therefore a natural miss, while the
> old entry ages out of the cache on its own. `flutter_cache_manager` is now a
> direct dependency in `pubspec.yaml` — it was already present transitively —
> because this code imports it rather than going through a widget.
>
> Measured on the emulator: after clearing `cache/libCachedImageData`, the
> first view wrote three files (640 KB, 860 KB, 875 KB); a second view 76
> seconds later left all three byte-for-byte and mtime-for-mtime unchanged,
> with the carousel still rendering.
>
> **Amendment, 2026-09-23 — one successful generation per day, and Studio
> shows it.** Owner's rule: the Daily Verse reference may be edited as often
> as the admin likes, but images may be generated **once a day**, and an
> edit made after that day's generation appears on tomorrow's card. This
> supersedes D8's "cap of 4" as the *product* rule; the cap remains only as a
> cost backstop.
>
> - **"Once" means once successfully.** `dailyGenerationUsed` (exported and
>   pure, like `decideLockOutcome`) reads the day as spent when **both**
>   languages are `ready`, whatever their fingerprints. A failed or partial
>   run therefore leaves the day open — chosen by the owner over a strict
>   one-press rule, so a bad Gemini day cannot cost a church its whole
>   allowance. A retry reuses any language already `ready` at the current
>   fingerprint, so only the missing one costs anything.
> - It is checked **after** `decideLockOutcome`, so an already-generated,
>   still-current day stays an idempotent `hit` rather than becoming an
>   error. Reaching the check with both languages ready means the fingerprint
>   moved — the verse was edited after the run — and that is rejected with
>   `failed-precondition: daily-generation-used`.
> - **Studio asks the server, not Firestore.** The obvious implementation is
>   an admin read of `dailyVerseCards/{dayKey}`; it was built, deployed and
>   reverted the same day. `isChurchAdmin` in both rules files compares the
>   caller's *lowercased* email against `config/app.admins` **as stored**, and
>   rules cannot lowercase the stored list — so an admin whose entry carries a
>   capital (real case in `tnbm`: `"Ephrim17@gmail.com"` vs the token's
>   `ephrim17@gmail.com`) is denied, and the button silently fails open.
>   `fetch` mode now returns `generationUsed`, computed server-side where
>   `authorize()` lowercases both sides. `firestore.rules` is back to
>   `allow read, write: if false`.
>
>   **This casing mismatch is a live, pre-existing bug beyond this feature.**
>   Any rule path gated on `isChurchAdmin` alone fails for such an admin
>   today; it is masked wherever `isChurchStaff` is used, because that also
>   accepts a super admin. Fixing it means normalising stored admin emails to
>   lowercase across churches — a data migration, not a rules change, and not
>   done here.
> - **The complete fallback is the old card.** When no day in the lookback
>   window has cards for the toggled language, the section renders the verse
>   as plain text with its reference pill and the same toggle — the card this
>   section had before it showed images — instead of the "not created yet"
>   message. That message now appears only if the verse text itself cannot be
>   read.
>
> - **The run is blocked and shows a percentage.** `generateDailyVerseCards\
>   BothLanguages` reports each language as it settles, and Studio turns that
>   into a modal `BlockingPercentProgressDialog`. The maths lives in the pure
>   `verseImageGenerationProgress`: a language owns half the bar, creeps
>   through its own half on elapsed time capped at 92% of it, and only fills
>   that half when the callable actually returns for it. There is no honest
>   finer signal — Gemini streams nothing — and the cap is what stops the bar
>   claiming a step finished before it is. Blocking is deliberate: this is the
>   church's one paid run for the day, so a second press or a mid-flight verse
>   edit must be impossible.
>
> Verified live on the emulator, 2026-09-23, with the verse edited to
> Joshua 1:1 after the day's generation: Studio's button disabled with its
> info line; For You in Tamil showing the 22 September card; For You in
> English dropping to the plain-text Joshua 1:1 card.

> **Still uncached: the callable itself.** Every visit to For You invokes
> `generateVerseBackgroundImage` in `fetch` mode (one function invocation plus
> a small number of Firestore reads) purely to learn the card URLs it already
> fetched last time. The images were the dominant cost and are now gone;
> closing this one too would mean holding the returned cards locally for a
> bounded window, which trades a little staleness when an admin regenerates
> mid-day. Not done — raise it with the owner before implementing.

---

## 2. Why

### 2.1 Cost scales with active users, not with content

`generateVerseBackgroundImage`
(`functions/src/verseImage.ts:502`) fires three `callGeminiImageGeneration`
calls in a `Promise.allSettled` batch (`verseImage.ts:550`) against
`gemini-3-pro-image` (`verseImage.ts:20`) and returns the images as base64 to
exactly one caller. Nothing is persisted anywhere.

Verified figures (do not re-derive):

- `gemini-3-pro-image`, 1K output (no resolution parameter is sent, so 1K is
  the default): **$0.134/image = ₹12.85** at ₹95.9/USD.
- One generate action = 3 candidates = 3 API calls = **$0.402 ≈ ₹38.55**,
  plus ~3,700 prompt input tokens (~₹0.70).
- Thinking-token output ($12/1M) is **currently unmeasured** — the function
  never logs `usageMetadata`. Phase 0 fixes that.

For a church of 100 members who each tap Generate once, the church pays
100 × ₹38.55 ≈ **₹3,900/day** for what is, by definition, *the same verse*.

### 2.2 Members of the same church get different cards

Three styles are deliberate (`for-you-content.md`, "Generate with AI"), but
the *specific* image is a fresh roll per user. Two members sharing "the
church's verse of the day" to the same WhatsApp group send two unrelated
graphics. For a church-branded daily artefact, that is the wrong product
behaviour, not just a cost problem.

### 2.3 Every user waits 60-99s

`_AiVerseImageGenerationDialog` (`verse_share_modal.dart:290`) is a
`PopScope(canPop: false)` non-dismissible dialog. Measured generation is
60-99s per action (`for-you-content.md`, spelling-accuracy fix note). Every
user pays that wait, every day.

### 2.4 A failed generation currently burns the user's whole day

`reserveDailyQuota` (`verseImage.ts:47`) is called at `verseImage.ts:526`,
**before** any Gemini call. If all three candidates fail, the function throws
`generation-failed` at `verseImage.ts:562-564` and the reserved unit is never
returned. Verified: `grep -rn "FieldValue.increment(-1)\|refund" functions/src/`
returns **0 matches**. With `AI_IMAGE_DAILY_CAP=1` in production, one failure
locks the user out until the next UTC day.

---

## 3. Current-state audit

### 3.1 The Daily Verse share path

`DailyVerseCard` (`daily_verse_section.dart:41`) watches
`dailyVerseProviderLocal` (`daily_verse_providers.dart:5`) and
`dailyVerseLanguageProvider` (`language_provider.dart`, **defaults to
`BibleLanguage.tamil`**). Its share `IconButton` calls
`showVerseShareChoiceSheet` (`daily_verse_section.dart:82`) with the toggled
language's text and reference — so Daily Verse never shows the
English/Tamil sheet; the toggle already carries the choice.

`showVerseShareChoiceSheet` (`verse_share_modal.dart:75`) routes to
`_startAiVerseShareFlow` (`:265`) or `showVerseShareModal` (`:49`).

### 3.2 Where the verse text actually comes from

`dailyVerseProviderLocal` reads `config.dailyVerseRef` — parsed from
`churches/{churchId}/config/app.dailyVerse` (`app_config_model.dart:87`,
written by `StudioRepository.updateDailyVerse`,
`studio_repository.dart:587`) — then calls `BibleRepository.getVerse`
(`bible_book_repository.dart:65`), which returns
`{tamil, english, reference, referenceTamil}`. `referenceTamil` comes from
`_tamilBookName` (`bible_book_repository.dart:100`) against
`catalog.bibleBooks`.

**The Bible text is not bundled.** `pubspec.yaml` ships no `assets/bible/`
directory; the only version is `fallbackBibleVersions`
(`bible_catalog.dart:77`) with `storagePath: 'bible/english_tamil'`
(`bible_catalog.dart:85`), loaded through
`BibleDownloadRepository._loadSourceFile`
(`bible_download_repository.dart:177`) from Firebase Storage
`bible/english_tamil/{Book}.json`. `storage.rules:55` gives that prefix
`allow read: if true`.

This is the enabling fact for D5: the Cloud Function can resolve the verse
text itself with the Admin SDK.

### 3.3 The Bible version is a device-local preference

`BibleDownloadRepository.selectedVersion` (`bible_download_repository.dart:41`)
reads a SharedPreferences key and resolves it through
`bibleVersionById` (`bible_catalog.dart:92`). There is exactly one version
today, so every device produces identical text for a given reference.

**Latent bug found while researching, out of scope:**
`bible_library_screen.dart:275` calls `setSelectedVersion` with a version
sourced from the Firestore `bible_versions` collection, but
`bibleVersionById` only searches the hardcoded `fallbackBibleVersions` list —
any id other than `'english_tamil'` silently falls back to the default. Worth
a separate ticket. It does **not** affect this plan, because D5 makes the
server the single source of verse text.

### 3.4 Quota plumbing

`users/{uid}/aiUsage/{yyyy-mm-dd}.count`, written only by the Admin SDK;
`firestore.rules:400` allows the owner read and no client write.
`todayKey()` (`verseImage.ts:35`) was **UTC** and `unlimitedTestEmail`
bypassed the cap for one account. **Update 2026-09-28:** `todayKey()` now
returns `istToday().dayKey`, so the per-user cap resets at 12am IST like the
church cache, and `unlimitedTestEmail` has been removed.

### 3.5 Guest sharing

`isGuestShare: true` is passed from exactly three places, all in
`church_side_drawer.dart` (Bible library `:312`, Favourites `:326`, reading
plans `:334`). The Daily Verse call site passes nothing, so it is always
`false`. **Daily Verse can never be a guest share** — D16.

### 3.6 Existing scheduled-function and timezone precedent

`onSchedule` is already used three times (`index.ts:1592`,
`youtube_live.ts:130`, `:206`). `recurringEventTimeZone = "Asia/Kolkata"`
(`index.ts:121`) is the existing precedent for a church-local day boundary.

### 3.7 Storage rules today

`storage.rules` has `isChurchAdmin`, `isSuperAdmin`, `isChurchStaff`,
`hasVerifiedEmail`, `isUnclaimedChurch` — but **no `isApprovedMember`**. The
feed prefixes (`storage.rules:67-78`) are `allow read/write: if isSignedIn()`,
which is the permissive state `CLAUDE.local.md` flags. There is no catch-all
allow, so a new prefix is denied by default until a match block is added.

---

## 4. Target design

### 4.1 Flow

```
Daily Verse share icon
  └─ choice sheet ── "Create manually" ──► VerseShareModal   (UNCHANGED)
                   └ "Generate with AI"
                        └─ callable getDailyVerseCards(churchId, language)
                             ├─ ready      → {status:'ready', cards:[{style,path}...]}
                             │                └─ client getData() ×3 → existing swipe screen
                             ├─ generating → {status:'generating'} → "being prepared" + Retry
                             └─ failed     → HttpsError → friendly failure text
```

### 4.2 Firestore: one doc per church-day

`churches/{churchId}/dailyVerseCards/{dayKey}` — `dayKey` is
`YYYY-MM-DD` in **Asia/Kolkata**.

```jsonc
{
  "dayKey": "2026-09-18",
  "attemptCount": 1,                 // Gemini batches started today, success or not
  "expireAt": "<Timestamp: dayKey + 14 days>",   // Firestore TTL field
  "languages": {
    "ta": {
      "status": "ready",             // "generating" | "ready" | "failed"
      "fingerprint": "a3f19c02b7de",
      "reference": "சங்கீதம் 5:3",
      "verseRef": {"book": "Psalms", "chapter": 5, "verse": 3},
      "cards": [
        {"style": "infographic",      "path": "dailyVerseCards/<cid>/2026-09-18/ta-infographic-a3f19c02b7de.jpg"},
        {"style": "devotionalPoster", "path": "dailyVerseCards/<cid>/2026-09-18/ta-devotionalPoster-a3f19c02b7de.jpg"},
        {"style": "moodBackground",   "path": "dailyVerseCards/<cid>/2026-09-18/ta-moodBackground-a3f19c02b7de.jpg"}
      ],
      "startedAt": "<Timestamp>",
      "completedAt": "<Timestamp>",
      "failedAt": null,
      "generatedBy": "<uid>"
    },
    "en": { /* same shape, absent until English is first requested */ }
  }
}
```

The doc is **Admin-SDK-only** — `allow read, write: if false` in
`firestore.rules`. Clients never read it; they call the callable.

### 4.3 The fingerprint (D4)

`fingerprint = sha256(JSON.stringify([...])).slice(0, 12)` over, in order:

1. `churchId`
2. `dayKey`
3. `language` (`"en"` | `"ta"`)
4. server-resolved `book`, `chapter`, `verse` from `config/app.dailyVerse`
5. server-resolved `churchName` and `contactNumber` from `churches/{churchId}`
6. a `PROMPT_VERSION` constant bumped by hand whenever a prompt builder in
   `verseImage.ts` changes materially

Note what is **not** in it: the verse *text*. The text is a deterministic
function of (4) plus the single Bible version, so including it would only add
a client-controllable input. The fingerprint is embedded in the object
filename so a regeneration never overwrites an in-flight read.

Behaviour on mismatch (verse ref changed in Studio mid-day, church renamed,
contact number edited, prompts revised): treat as a cache miss, regenerate,
consume one unit of the per-church cap. Old objects are left to the lifecycle
rule; no in-request delete.

### 4.4 Storage layout (D10)

```
dailyVerseCards/{churchId}/{dayKey}/{lang}-{style}-{fingerprint}.jpg
```

**Why bucket root and not `churches/{churchId}/dailyVerseCards/`:** a GCS
lifecycle rule matches on a literal object-name prefix. It cannot express
`churches/*/dailyVerseCards/`. Rooting the prefix gives free, code-free
retention (D13) via one rule. Church scoping is preserved structurally — the
`churchId` is still the first path segment and the rules bind to it.

### 4.5 Storage rules

Add an `isApprovedMember(churchId)` helper to `storage.rules` mirroring
`firestore.rules:66`, plus:

```
match /dailyVerseCards/{churchId}/{dayKey}/{fileName} {
  allow read: if isApprovedMember(churchId) || isChurchAdmin(churchId);
  allow write: if false;   // Admin SDK only — see D11
}
```

`isChurchAdmin`, **not** `isChurchStaff` — `isChurchStaff` folds in
`isSuperAdmin()`, and super-admin status must never imply per-church access.

### 4.6 Callable contract

`getDailyVerseCards({ churchId: string, language: 'en' | 'ta' })`, region
`us-central1`, `timeoutSeconds: 180`, `secrets: [GEMINI_API_KEY]`.

Returns one of:

```jsonc
{"status": "ready",      "cards": [{"style": "...", "path": "..."}], "reference": "..."}
{"status": "generating"}
```

Throws:

| Code | message | Client shows |
|---|---|---|
| `unauthenticated` | `sign-in-required` | existing failure text |
| `permission-denied` | `not-a-member` | existing failure text |
| `failed-precondition` | `no-daily-verse` | existing failure text |
| `resource-exhausted` | `church-cap-exceeded` | existing `ai_quota_exceeded` text |
| `internal` | `generation-failed` | existing `ai_generation_failed` text |

### 4.7 Server algorithm

1. Require `request.auth.uid`. Require `churchId` to be a non-empty string.
2. Authorize: `churches/{churchId}/members/{uid}.approved == true`, **or**
   the caller's lowercased email is in `churches/{churchId}/config/app.admins`.
   Nothing else — super admin alone does not qualify (§7.2).
3. Compute `dayKey` and the human `dateLabel` ("18 September 2026") in
   Asia/Kolkata.
4. Read `churches/{churchId}/config/app.dailyVerse` → `{book, chapter, verse}`.
   Missing/invalid → `failed-precondition`.
5. Read `churches/{churchId}` → `name`, `contact`.
6. Compute `fingerprint`.
7. **Transaction** on `churches/{churchId}/dailyVerseCards/{dayKey}`:
   - entry `ready` and `fingerprint` matches → return `HIT`.
   - entry `generating`, `fingerprint` matches, `startedAt` within 240s →
     return `PENDING`.
   - entry `failed`, `fingerprint` matches, `failedAt` within 600s →
     return `FAILED_COOLDOWN`.
   - otherwise → if `attemptCount >= cap` throw `resource-exhausted`;
     else set the entry to `generating` with `startedAt`, `generatedBy`,
     `fingerprint`, bump `attemptCount`, set `expireAt`, return `LOCK`.
8. On `HIT` return the stored cards. On `PENDING` return
   `{status:'generating'}`. On `FAILED_COOLDOWN` throw `internal`.
9. On `LOCK`: download `bible/english_tamil/{book}.json` with the Admin SDK,
   extract the verse, pick the `tamil` or `english` field by language, and
   build the reference (English `"{book} {chapter}:{verse}"`; Tamil from
   `functions/src/bibleBooks.ts`, D18).
10. Run the existing three prompt builders unchanged
    (`buildInfographicPrompt`, `buildDevotionalPosterPrompt`,
    `buildBackgroundStylePrompt`) through the existing
    `callGeminiImageGeneration`, in the same `Promise.allSettled` batch.
    Log `usageMetadata` per call (Phase 0 adds this).
11. Upload each fulfilled candidate to its object path with
    `contentType: 'image/jpeg'`, `cacheControl: 'private, max-age=86400'`.
12. All three failed → set the entry `failed` with `failedAt` and
    `failureReason`, throw `internal`. At least one succeeded → set `ready`
    with the uploaded `cards` and `completedAt`, return them.

### 4.8 Client changes

In `verse_share_modal.dart`:

- New `Future<void> showCachedDailyVerseCards(BuildContext, {required String
  churchId, required VerseShareLanguage language})` — calls the callable,
  fetches bytes, pushes the **existing, unmodified**
  `_AiVerseCardSwipeScreen` (`verse_share_modal.dart:422`), whose `_download`
  (`:443`) therefore keeps working byte-for-byte.
- New `_DailyVerseCardLoadingDialog` mirroring
  `_AiVerseImageGenerationDialog` (`:290`) but with a short timeout (20s) and
  a **dismissible** barrier — a cache hit is a Firestore read plus three
  Storage reads, not a 99s generation. Only the cold-cache path can be slow,
  and that path returns `generating` rather than blocking.
- A session-scoped `Map<String, Uint8List>` byte cache keyed by object path,
  cleared when the returned `reference` changes, so re-opening within a
  session is instant.
- `showVerseShareChoiceSheet` gains an optional
  `DailyVerseCacheKey? dailyVerseCache` parameter. When non-null, the `ai`
  branch calls `showCachedDailyVerseCards`; when null it keeps calling
  `_startAiVerseShareFlow` exactly as today. The `manual` branch is untouched.

In `daily_verse_section.dart:82`, pass the cache key built from
`currentChurchIdProvider` (`church_provider.dart:31`) and
`dailyVerseLanguageProvider`. `favorite_verses_screen.dart:193` passes
nothing and is unaffected.

New text keys in `defaultChurchTextContents`
(`lib/church_app/models/text_content_defaults.dart`), English defaults:

| Key | Default |
|---|---|
| `ui.verse_share.daily_card_loading` | `Opening today's verse cards...` |
| `ui.verse_share.daily_card_preparing` | `Today's cards are being prepared. Please try again in a minute.` |
| `ui.verse_share.daily_card_retry` | `Try again` |

---

## 5. Cost model

At ₹95.9/USD. One generate action = 3 images = $0.402 = ₹38.55.

### Today (per user, per day)

| Churches | Generating users/church | Actions/day | USD/day | INR/day | INR/month (30d) |
|---|---|---|---|---|---|
| 1 | 10 | 10 | $4.02 | ₹385.52 | ₹11,566 |
| 1 | 100 | 100 | $40.20 | ₹3,855.18 | ₹115,655 |
| 10 | 50 | 500 | $201.00 | ₹19,275.90 | ₹578,277 |
| 50 | 50 | 2,500 | $1,005.00 | ₹96,379.50 | ₹2,891,385 |

### Proposed (lazy cache, one language per church per day)

| Active churches | Actions/day | USD/day | INR/day | INR/month (30d) |
|---|---|---|---|---|
| 1 | 1 | $0.402 | ₹38.55 | ₹1,157 |
| 10 | 10 | $4.02 | ₹385.52 | ₹11,566 |
| 50 | 50 | $20.10 | ₹1,927.59 | ₹57,828 |

Both languages requested doubles the proposed column. The per-church cap
(D8, default 3) puts a hard ceiling of **₹115.65/church/day**.

At 1 church × 100 generating members, that is ₹3,855 → ₹38.55/day, a **99.0%**
reduction. User count stops being a cost driver entirely.

### Why not a nightly cron (D1)

50 churches pre-generated nightly in both languages = 100 actions/day =
**₹3,855/day = ₹115,650/month, regardless of whether anyone opens the app.**
Lazy, with a realistic 20% of churches active in one language, is 10 actions/day
= **₹385.52/day = ₹11,566/month** — 10× cheaper for identical user-visible
behaviour after the first request of the day. The only thing the cron buys is
that the first requester of the day sees a hit instead of `generating`, which
D15 already handles with a retry affordance. A cron also needs every input
this design resolves server-side anyway, so it can be added later on top of
D5/D6 with no rework if that first-request wait ever becomes a real complaint.

Secondary costs, both negligible at these volumes: three Storage reads per
card view (~1.5MB, ~$0.12/GB egress) and one `firestore.get` per Storage read
from the rules in §4.5.

---

## 6. Phases

Each phase is independently shippable and has an explicit exit criterion. Run
the repo's release gates at the end of every phase:

```
flutter analyze lib/church_app test
flutter test
npm --prefix functions run lint && npm --prefix functions run build
```

### Phase 0 — Quota refund and usage logging (ships alone)

Scope: `functions/src/verseImage.ts` only. No caching work.

1. Add `refundDailyQuota(uid)` — a transaction that decrements
   `users/{uid}/aiUsage/{todayKey()}.count`, floored at 0.
2. Call it in `generateVerseBackgroundImage` on the
   `images.length === 0` path (`verseImage.ts:562`) before throwing. A partial
   success (1-2 candidates) still consumes the unit.
3. Log `usageMetadata` (prompt, output and thinking token counts) from each
   `callGeminiImageGeneration` response so thinking-token spend becomes
   measurable before Phase 2 changes the cost shape.

**Exit:** deployed; a forced total failure leaves `aiUsage.count` unchanged;
`firebase functions:log` shows per-call token counts. Verified by a human
against the live project.

### Phase 1 — Infrastructure (rules and retention, no behaviour change)

1. `storage.rules`: add `isApprovedMember(churchId)` and the
   `dailyVerseCards` match block from §4.5.
2. `firestore.rules`: add
   `match /dailyVerseCards/{dayKey} { allow read, write: if false; }` **inside**
   the existing `match /churches/{churchId}` block.
3. GCS lifecycle rule, 14-day delete on prefix `dailyVerseCards/`
   (§7.6 — merge, do not replace).
4. Firestore TTL policy on collection group `dailyVerseCards`, field
   `expireAt`.

**Exit:** rules deployed; a manually-uploaded probe object under
`dailyVerseCards/<churchId>/…` is readable by an approved member of that
church, denied to a member of a *different* church, denied to a signed-in
non-member, and denied for write to everyone including a church admin.
Verified by a human.

### Phase 2 — `getDailyVerseCards` callable

New file `functions/src/dailyVerseCards.ts`, exported from
`functions/src/index.ts`. New `functions/src/bibleBooks.ts` (D18). Prompt
builders and `callGeminiImageGeneration` are **reused from `verseImage.ts`**
(export them; do not copy them). New `DAILY_VERSE_CARD_DAILY_CAP=3` in
`functions/.env.example` and the production env file.

No client change in this phase.

**Exit:** with the emulator or `firebase functions:shell`:
two concurrent cold calls produce exactly **one** Gemini batch and one
`PENDING`; a second call after completion returns `ready` with zero Gemini
calls; `users/{uid}/aiUsage` is untouched by every one of those calls;
objects land at the §4.4 path; a call with another church's `churchId` is
`permission-denied`. **This is the phase where a mistake costs money — verify
the cap and the lock by a human before any wider rollout.**

### Phase 3 — Client switch

`verse_share_modal.dart` additions from §4.8, the
`daily_verse_section.dart:82` call site, and the three new text keys. Tests
in `test/` (no mocking library — use fakes, per `CLAUDE.md`).

**Exit:** two different accounts in the same church, same day, same language
see **identical** cards; the second opens in under ~3s with no generation
dialog; switching the language toggle and generating produces a distinct
second cache entry; "Create manually" is byte-identical in behaviour; the
Bible reader's long-press generate and Favourites sharing still consume
`aiUsage` and still work.

### Phase 4 — Documentation

§9 and §11 below.

**Exit:** `KT Files/features/for-you-content.md` and
`bible-and-favorites.md` describe the shipped behaviour and carry the new
numbered flows; the duplicate-ID bug in §11.3 is fixed.

---

## 7. Critical correctness notes

### 7.1 Do not let the client supply the prompt inputs

**Don't** keep the current shape where the client sends `verseText`,
`churchName`, `contactNumber` and `dateLabel`. On the *uncached* path that only
lets a user affect their own image. On a *cached* path it lets any approved
member land arbitrary text — including abuse — into the card that **every
member of that church sees for the rest of the day**, on the first request of
the day. This is the single most important difference between the old and new
functions. Resolve all five inputs server-side (D5, D6). The client sends only
`churchId` and `language`.

### 7.2 Do not authorize with `isChurchStaff`-style logic

**Don't** accept a caller because they are a super admin. Per `AGENTS.md` and
the repo's authority model, super admin is global and separate; it must never
imply per-church access or per-church actions. The callable authorizes on
approved membership of *that* `churchId`, or that church's `config/app.admins`
list — nothing else. Likewise use `isChurchAdmin`, not `isChurchStaff`, in the
Storage rule (§4.5).

### 7.3 Do not trust the client's `churchId` without checking membership

A member of church A must never be able to spend church B's daily cap or read
church B's cards. Step 2 of §4.7 is not optional, and the Storage rule binds
read access to the same `churchId` that appears in the object path.

### 7.4 Do not reserve the lock outside a transaction

Two users hitting a cold cache simultaneously must not both start a ₹38.55
batch. The read of the entry's status and the write of `generating` must be in
the **same** `runTransaction`, exactly as `reserveDailyQuota`
(`verseImage.ts:47`) already does for the per-user counter. Do a
read-then-write and you will pay double on every cold morning.

### 7.5 Do not leave a lock permanently stuck

If the function crashes or is killed after taking the lock, the entry stays
`generating` forever and the church never gets cards again that day. The 240s
stale-lock takeover (§4.7 step 7) is what prevents that; 240s is chosen to
exceed the function's own 180s `timeoutSeconds`.

### 7.6 Do not overwrite the bucket's lifecycle configuration

`gcloud storage buckets update --lifecycle-file=...` **replaces** the entire
lifecycle config. Read the current config first, merge the new rule in, then
apply. Blowing away an existing rule on this bucket would affect Bible
downloads, church logos and feed images.

### 7.7 Do not regenerate into the same object name

Put the fingerprint in the filename (§4.4). If a mid-day verse change
overwrote `ta-infographic.jpg` in place, a client that already has the old
path could read a half-written object, and CDN/edge caching would serve mixed
content. New fingerprint, new name; the old object expires on its own.

### 7.8 Do not use UTC for the day key

`todayKey()` (`verseImage.ts:35`) is UTC, and the client's current
`dateLabel` uses device-local time. For India that means between 00:00 and
05:30 IST the cache key and the date printed on the card disagree, and the
cache rolls over mid-morning. Use `Asia/Kolkata` for both, matching
`recurringEventTimeZone` (`index.ts:121`).

### 7.9 Do not charge `users/{uid}/aiUsage` on the Daily Verse path

With `AI_IMAGE_DAILY_CAP=1`, charging the first requester of the day would
make one member pay their entire personal quota to produce a card for
everyone else, and would block them from using the Bible reader's generate
action. The cost unit is now the church, so the cap belongs to the church
(D8). The per-user cap stays in force, unchanged, on
`generateVerseBackgroundImage`.

### 7.10 Count failed attempts against the per-church cap

If only successes counted, a verse that reliably trips a safety filter would
retry on every member's tap, unbounded. Every batch *started* bumps
`attemptCount`. The 600s failure cooldown (§4.7 step 7) is a second brake.

### 7.11 Check the rules for nested wildcard shadowing

Re-verified for this design: `dailyVerseCards/{churchId}/…` in `storage.rules`
is a new top-level block under `match /b/{bucket}/o` and shadows nothing;
`match /dailyVerseCards/{dayKey}` in `firestore.rules` sits inside
`match /churches/{churchId}` and introduces no second `churchId`. Keep it that
way — nested wildcard shadowing has caused a real silent production bug in
this repo.

### 7.12 Rules `get()` budget

The new Firestore block is `if false`, so it adds **zero** `get()` cost. The
Storage read rule adds one `firestore.get` per object read (three per card
view). That is acceptable at this volume; do not add a second lookup to it.

---

## 8. Blast radius

**New files**

- `functions/src/dailyVerseCards.ts`
- `functions/src/bibleBooks.ts`
- `test/daily_verse_card_cache_test.dart`
- `test/bible_book_names_parity_test.dart` (D18 guard)

**Modified — Cloud Functions**

- `functions/src/verseImage.ts` — Phase 0: `refundDailyQuota`, call it on the
  all-candidates-failed path, log `usageMetadata`. Phase 2: export
  `callGeminiImageGeneration`, `buildInfographicPrompt`,
  `buildDevotionalPosterPrompt`, `buildBackgroundStylePrompt`. Prompt *text*
  unchanged.
- `functions/src/index.ts` — export `getDailyVerseCards`.
- `functions/.env.example`, `functions/.env.flutterlearning-c9f6c` —
  `DAILY_VERSE_CARD_DAILY_CAP=3`.

**Modified — rules and infrastructure**

- `storage.rules` — `isApprovedMember`, `dailyVerseCards` match block.
- `firestore.rules` — `dailyVerseCards` deny-all block inside
  `match /churches/{churchId}`.
- GCS bucket lifecycle configuration (console/gcloud, not in-repo).
- Firestore TTL policy on collection group `dailyVerseCards` (not in-repo).

**Modified — Flutter**

- `lib/church_app/widgets/modals/verse_share_modal.dart` —
  `showVerseShareChoiceSheet` gains an optional cache key; new
  `showCachedDailyVerseCards`, `_DailyVerseCardLoadingDialog`, byte cache.
  `VerseShareModal`, `_startAiVerseShareFlow`, `generateAiVerseCards`,
  `showVerseLanguageChoiceSheet` and `_AiVerseCardSwipeScreen` are untouched.
- `lib/church_app/screens/for_you/sections/daily_verse_section.dart` — pass
  the cache key at `:82`.
- `lib/church_app/models/text_content_defaults.dart` — three keys (§4.8).

**Explicitly not touched**

- `lib/church_app/screens/side_drawer/bible_book_screen.dart` (`:573-581`)
- `lib/church_app/screens/side_drawer/favorite_verses_screen.dart` (`:193`)
- `lib/church_app/services/firestore/firestore_paths.dart` — no client
  Firestore access to the cache doc, so no path helper is needed.

---

## 9. Test plan

### 9.1 New numbered flows — `for-you-content.md`

Use IDs from FORYOU-21 onward (FORYOU-19 and FORYOU-20 are currently
duplicated — see §11.3).

| ID | Scenario | Expected result |
|---|---|---|
| FORYOU-21 | Two accounts, same church, same day, same language, both tap Generate with AI | Both see the **same** 3 cards. The second opens in ~seconds with no generation dialog. |
| FORYOU-22 | Tap Generate with AI while another member's generation is in flight | Friendly "being prepared, try again in a minute" with a retry action — never a stuck spinner, never a second generation. |
| FORYOU-23 | Generate in Tamil, switch the language toggle to English, generate again | Two distinct card sets, each in the right script with the right reference; two cache entries; two cap units consumed. |
| FORYOU-24 | Admin changes the Daily Verse reference in Studio mid-day, then a member generates | Cards regenerate for the new verse; the old cards are not served. |
| FORYOU-25 | Exhaust the per-church daily cap, then generate | Friendly limit message; no Gemini call; "Create manually" still works. |
| FORYOU-26 | Generate from the Daily Verse card, then use the Bible reader's long-press Generate AI image | The reader path still generates on demand and still consumes the per-user daily cap — the Daily Verse action did not consume it. |
| FORYOU-27 | Member of church A signed in; attempt a `getDailyVerseCards` call for church B (negative permission test) | `permission-denied`; church B's cap is unchanged and its objects are unreadable. |
| FORYOU-28 | Download from the cached card viewer on Android and on web | Image saves exactly as it does today; the currently-visible candidate is the one saved. |
| FORYOU-29 | AI generation fails completely on the Daily Verse path | Friendly failure text; the next tap within 10 minutes does not restart a generation; the per-church cap reflects one attempt. |

### 9.2 New numbered flow — `bible-and-favorites.md`

| ID | Scenario | Expected result |
|---|---|---|
| BIBLE-23 | Long-press a verse, Generate AI image, twice in one day as the same user | Second attempt hits the per-user daily cap with the friendly message — the reader path is **not** cached and is unaffected by the Daily Verse cache. |

### 9.3 Existing flows that must be re-run

- `for-you-content.md`: **FORYOU-14** (choice sheet), **FORYOU-15** (3-style
  swipeable picker, page dots, download), **FORYOU-16** (quota message),
  **FORYOU-17** (three distinct styles), **FORYOU-18** (no church logo /
  guest no-branding), both **FORYOU-19** entries (lament-verse imagery and
  the manual branding pill), both **FORYOU-20** entries (praise-verse imagery
  and the slow-generation timeout), **FORYOU-03** (Daily Verse reference).
- `bible-and-favorites.md`: **BIBLE-14** (summary cap — confirms Phase 0's
  refund did not disturb the summary quota), **BIBLE-15**, **BIBLE-15b**,
  **BIBLE-15c**, **BIBLE-16** (guest, no branding).

### 9.4 Automated tests

- `test/daily_verse_card_cache_test.dart` — the client-side decision logic:
  `ready` renders the swipe screen, `generating` renders the retry state,
  `resource-exhausted` maps to the quota text, `internal` maps to the failure
  text. Real objects and fakes; no mocking library (`CLAUDE.md`).
- `test/bible_book_names_parity_test.dart` — reads
  `functions/src/bibleBooks.ts` as text and asserts every
  `catalog.bibleBooks` key/Tamil-name pair appears in it (D18).

### 9.5 Gates

Phase exit gates are listed per phase in §6. `flutter build apk/ios/web
--release` is not required for these phases (see `README.md`).

---

## 10. Out of scope

- **Bible reader long-press "Generate AI image"** and **Favourites sharing**
  (`bible_book_screen.dart:573-581`, `favorite_verses_screen.dart:193`) — an
  arbitrary user-chosen verse cannot be pre-generated per church. Stays
  on-demand, stays per-user capped (D17).
- **Guest / no-church card caching** — Daily Verse is unreachable as a guest
  share (§3.5), so there is nothing to cache globally (D16).
- **"Create manually"** — zero changes (D20).
- **A nightly cron / hybrid scheduler** — rejected on cost in §5. The
  server-side input resolution in D5/D6 leaves the door open with no rework.
- **A Studio "regenerate today's cards" button** (D19).
- **Compositing the church's real logo onto a finished card** — already noted
  as a possible follow-up in `for-you-content.md`, unrelated to caching.
- **The `bibleVersionById` fallback bug** (§3.3) — separate ticket.
- ~~**Removing `unlimitedTestEmail`**~~ — done 2026-09-28.
- **Tightening the permissive `churches/{churchId}/feed[s]` Storage rules**
  (`storage.rules:67-78`) — real, flagged in `CLAUDE.local.md`, but a
  different change with a different blast radius.

---

## 11. Documentation updates this plan implies

### 11.1 `KT Files/features/for-you-content.md` (owner of AI verse-card behaviour)

- Rewrite the "Generate with AI" bullet: cards are generated **once per church
  per day per language** and served from Storage to every member; the 3-style
  design, spelling-accuracy and verse-context behaviour are unchanged; the
  long loading dialog is replaced by a fast load plus a "being prepared"
  state on a cold cache.
- Replace the per-user cap sentence for this path with the per-church cap
  (`DAILY_VERSE_CARD_DAILY_CAP`), and state plainly that the per-user
  `AI_IMAGE_DAILY_CAP` still governs the reader and Favourites paths.
- Extend the technical map: `functions/src/dailyVerseCards.ts`
  (`getDailyVerseCards`), `churches/{churchId}/dailyVerseCards/{dayKey}`
  (Admin-SDK-only), Storage `dailyVerseCards/{churchId}/{dayKey}/…`, 14-day
  retention.
- Add FORYOU-21 … FORYOU-29.

### 11.2 `KT Files/features/bible-and-favorites.md`

- State explicitly that the reader's long-press "Generate AI image" and
  Favourites sharing remain **on-demand and per-user capped**, and are
  deliberately not cached.
- Add BIBLE-23.

### 11.3 Documentation bug found during research (fix in Phase 4)

`KT Files/features/for-you-content.md` has **duplicate test-flow IDs**:
`FORYOU-19` is used twice (lament-verse imagery, and the manual-card branding
pill) and `FORYOU-20` is used twice (praise-verse imagery, and the
slow-generation timeout). Confirmed with:

```
grep -n "FORYOU-" "KT Files/features/for-you-content.md" | awk -F'|' '{print $2}' | sort | uniq -d
```

Re-number the second of each pair before adding FORYOU-21 onward. Nothing
under `KT Files/testing/` cites these IDs (`grep -rn "FORYOU-" "KT Files/testing/"`
returns nothing), so the renumbering is contained to this one file.

### 11.4 `KT Files/architecture/system-architecture.md`

Add `dailyVerseCards/{churchId}/{dayKey}/…` to the "Storage ownership" prefix
list, noting it is lifecycle-managed rather than deleted by application code.
