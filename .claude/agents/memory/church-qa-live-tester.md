# qa-live-tester memory

Durable learnings only — confirmed test accounts, environment quirks,
coordinate/gesture gotchas specific to this emulator setup, bugs whose root
cause turned out to be non-obvious. Not a log of routine test runs. Keep
entries terse; prune anything superseded or turned out wrong.

## Known-safe test accounts

- `ephrim17@gmail.com` — confirmed signed in on `emulator-5554` during the
  2026-09-14 Bible-feature QA pass. Matches `unlimitedTestEmail` in both
  `functions/src/bibleSummary.ts` and `functions/src/verseImage.ts`, so it's
  safe to spend chapter/verse AI-summary and verse-image quota on it. Note:
  because the cap check (`reserveDailyQuota`) is skipped entirely for this
  email, no `bibleSummaryUsage/{yyyy-mm-dd}` doc is ever written for its
  calls — you cannot exercise the "cap exceeded" friendly-message path
  (BIBLE-14) on this account; that needs a non-bypassed account, which then
  triggers the golden-rule caution around real accounts/quota.

## Environment/device quirks

- `emulator-5554` is 1080x2424 real pixels; the screenshot image shown to
  you when you Read a screencap PNG is downscaled to ~891x2000 (confirmed
  via `file <png>`). Coordinates you eyeball from the *displayed* image
  must be multiplied by ~1.212 before passing to `adb shell input
  tap/swipe`. Mixing this up is easy and silent — a tap can land on a
  popup menu's neighboring row (or miss the popup onto the text behind it)
  with no error, so double check any interactive popup (e.g. the Bible
  reader's long-press verse menu, which has two stacked rows ~50px apart
  in real pixels) by re-screenshotting after the tap rather than assuming
  it landed.
- `uiautomator dump` on this app returns an essentially empty semantic
  tree (just generic FrameLayout/LinearLayout nodes, no text/bounds for
  in-app widgets) on at least the Bible reader screens — Flutter semantics
  aren't exposed there. Coordinate-based tapping (scaled per above) is the
  only option on those screens; the dump-and-grep-bounds technique only
  works on screens that do expose semantics (e.g. the side drawer did
  return real bounds for "Holy Bible").
- Toggling a Bible verse highlight has a visible multi-second lag between
  the popup action and the yellow background actually appearing/
  disappearing: `toggleGlobalHighlight` writes Firestore, then
  `ref.invalidate(favoritesProvider)` triggers `loadFavorites()`, which
  re-fetches all favorite keys from Firestore *and* re-reads the bundled
  Bible JSON per key. A screenshot taken immediately after the tap can
  look like "nothing happened" even though the write already succeeded —
  confirm via Firestore (`users/{uid}/favorites/{Book_chapter_verse}`)
  before concluding a highlight tap silently failed.

- A running debug session (`flutter run`/`debug_adapter`, e.g. one left
  attached by an IDE) does **not** pick up source edits made after it
  started unless something actually triggers a hot reload/restart on it.
  Before trusting "the debug build already has the change," compare the
  edited file's mtime (`stat -f "%Sm %N" <file>`) against the resident
  process's start time (`ps -o pid,lstart,command -p <pid>`) — if the file
  is newer, the running app is stale. You cannot safely attach a second
  `flutter attach`/`flutter run` to a VM service that already has a DDS
  client connected (fails with `HttpException: Connection closed before
  full header was received` even when pointed at the right forwarded
  port) — trying different ports just spins up more dangling `adb forward`
  entries. The reliable fix: kill the old resident processes (the
  `run --machine`/`debug_adapter` dartvm processes and the
  `development-service` DDS process), `adb shell am force-stop
  <package>`, then start a fresh `flutter run -d emulator-5554` yourself
  (background it, drive it via a FIFO stdin if you need hot-reload keys,
  poll its log for "Flutter run key commands" as the ready signal). This
  costs a Gradle build (~20-30s) but is the only sure way to test a change
  made in the same session as a pre-existing debug attach.
- Popup-menu row positions are easy to mis-eyeball even after remembering
  the 1.212 displayed→real scale factor — misjudging which row is which
  in a 3-item `showMenu` (e.g. the Bible long-press menu) produces a tap
  that silently dismisses the menu with no selection (no error, menu just
  closes, screen looks unchanged). Since `uiautomator dump` gives no
  bounds on these screens (see below), the reliable technique is: take
  the screenshot with the menu open, then `sips -c <h> <w> --cropOffset
  <top> <left> -o crop.png shot.png` on a generous real-pixel region and
  Read the crop — at native crop resolution the rows are unambiguous —
  before computing the tap point. Don't trust a by-eye estimate from the
  full downscaled screenshot for stacked menu items.

## 2026-09-15: AI verse-card spelling fix (gemini-3-pro-image + verbatim icon labels)

Verified live on `emulator-5554` as `ephrim17@gmail.com`. `functions/src/verseImage.ts`
switched `geminiImageModel` from `gemini-3.1-flash-image` to `gemini-3-pro-image`,
added a shared explicit spelling-proofread instruction to all 3 style prompts, and
changed the infographic style's icon-label callouts to require verbatim
verse-text excerpts instead of invented short labels.

- **Latency**: both test runs (Tamil Psalm 5:3, English Psalm 5:3) completed
  all 3 candidates well inside budget — observed wall-clock from tap to
  finished swipeable result was ~99s and ~74s respectively (upper bounds
  from 60s-granularity polling; actual completion may have been sooner).
  Comfortably under the 130s client timeout and 180s function timeout, and
  no per-candidate 90s abort fired (all 3 candidates succeeded both times).
  Confirmed via `firebase functions:log --only generateVerseBackgroundImage`
  that the invocation timestamp matched the tap (device clock is IST,
  UTC-5:30, when reading Cloud Functions log timestamps).
- **Spelling accuracy is now reliably correct for the previously-documented
  bug**: the mixed-script reference "(Psalms 5:3)"/"Psalms 5:3" rendered
  inside a Tamil-script card — the specific case documented as garbled in
  `KT Files/features/for-you-content.md` — came out correctly spelled in
  all 3 Tamil candidates and all 3 English candidates. The infographic
  style's icon-label callouts (previously producing invented, sometimes
  garbled text like "oreak word") are now genuinely verbatim words/phrases
  lifted from the verse in every candidate checked (Tamil: "காலையிலே",
  "காத்திருப்பேன்", "ஆயத்தமாகி"; English: "My voice", "in the morning",
  "look up") — no garbled letterforms observed anywhere across 6 candidates
  (2 generations × 3 styles).
- **New, smaller residual issue found** (not the originally-reported bug):
  the mood-background style (3rd candidate) for the **Tamil** card dropped
  one word from the verse — rendered "...காலையிலே உமக்கு நேரே ஆயத்தமாகி..."
  omitting "வந்து" which is present in the source text between "நேரே" and
  "ஆயத்தமாகி". Letters themselves were correctly spelled; this is a content
  omission, not a garbling. Worth re-checking on a future pass but did not
  block this fix's core goal (letter-level spelling accuracy).
- Minor cosmetic-only observations, not spelling issues: the devotional-poster
  style sometimes renders the verse reference as its own colored phrase
  strip and repeats the full verse (rather than a short takeaway) in the
  concluding navy banner; the English mood-background candidate had one
  stray unpaired closing quotation mark after the verse text; one Tamil
  devotional-poster footer rendered the "for prayer" phone icon looking
  like a prohibition/no-phone glyph rather than a plain phone silhouette.
- **UI gotcha reconfirmed**: the Bible reader's long-press verse menu and
  the Daily Verse card's share-sheet ("Generate with AI" row) are both easy
  to mis-tap by eyeballing the downscaled screenshot even after applying
  the 1.212 scale factor — two separate mis-taps here silently dismissed
  the menu/sheet with no error and no logcat output. The reliable fix used
  successfully: screenshot with the menu/sheet open, `sips -c <h> <w>
  --cropOffset <top> <left>` a generous region, Read the crop (its
  coordinates map 1:1 to real device pixels, no further scaling needed),
  then tap the row's center computed from the crop offset.

## Bugs whose real root cause was non-obvious

- **2026-09-14: "Generate AI image" long-press action hangs forever on
  "Creating your images..."** — the new long-press menu item correctly
  skips the "AI vs manual" choice sheet and goes straight into
  `generateAiVerseCards` → `generateVerseBackgroundImage` (confirmed via
  `firebase functions:log --only generateVerseBackgroundImage`: the
  invocation lands right on tap, "AppCheck rejected but allowed" warning
  logged at the matching timestamp). But the call never completes: no
  further log line appears for that invocation (no success, no thrown
  error, nothing) — the deployed function's Cloud Run `service_config`
  shows `timeoutSeconds: 60` (no explicit `timeoutSeconds` in the
  `onCall({region, secrets})` options in `functions/src/verseImage.ts`,
  so it's the v2 default), while the handler kicks off **3 parallel**
  full Gemini image-generation calls (`Promise.allSettled` over
  infographic/devotional-poster/background prompts) — plausible that one
  or more routinely exceeds the 60s budget, and Cloud Run kills the whole
  instance mid-request rather than returning the partial-success shape
  the handler is written to produce. Client-side, `adb logcat` shows an
  `okhttp.OkHttpClient` `InterruptedIOException: timeout` /
  `StreamResetException: stream was reset: CANCEL` roughly 45-50s after
  the tap — but this does **not** propagate to the Dart
  `on FirebaseFunctionsException`/`catch (_)` handler in
  `_AiVerseImageGenerationDialogState._generate()`: the dialog
  (`PopScope(canPop: false)`, `barrierDismissible: false`) stays stuck on
  the spinner indefinitely (verified 9+ minutes, never recovers) with no
  error snackbar ever shown. This blocked verifying the actual 3-candidate
  swipeable picture, the devotional-poster style check, and the download
  step — none of that could be exercised. Next step for whoever picks
  this up: bump `timeoutSeconds` on the `onCall` config (and/or
  `available_cpu`/`available_memory`) to comfortably cover 3 parallel
  Gemini image calls, and separately fix the client so a
  server-side-timeout/stream-reset always surfaces as a dismissible error
  instead of leaving a non-cancelable dialog stuck forever.
