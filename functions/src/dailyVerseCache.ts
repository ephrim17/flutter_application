import {createHash, randomUUID} from "crypto";
import {logger} from "firebase-functions";
import {defineString} from "firebase-functions/params";
import {HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {firestoreDb} from "./firestoreDb";

// Hard cost backstop on generation batches a single church may start per day,
// successful or not. The *product* rule — one successful generation per day —
// is `dailyGenerationUsed` below; this cap exists only so that repeated
// failures, which deliberately leave the day open for a retry, cannot run the
// bill away. One "Generate images" press does both languages, so 2 covers a
// normal day and 4 leaves room for one full retry after a failed run.
// See KT Files/architecture/daily-verse-card-caching.md (D8).
const dailyVerseCardDailyCap = defineString(
  "DAILY_VERSE_CARD_DAILY_CAP",
  {default: "4"},
);

// Longer than the function's own 180s timeout, so a lock is only ever taken
// over after the invocation that set it could not still be running.
const LOCK_STALE_MS = 240_000;
// A verse that trips a safety filter would otherwise re-enter generation on
// every member's tap until the cap is gone. Hold the failure briefly instead.
const FAILURE_COOLDOWN_MS = 600_000;

// How many earlier church-days a fetch may fall back to when today's cards
// are missing. Members should see *something* rather than an empty card, so
// the most recent day that still has ready cards is served instead. Bounded
// well inside D13's 14-day retention so the paths it returns still exist in
// Storage.
const FALLBACK_LOOKBACK_DAYS = 7;

// Bumped by hand whenever a prompt builder in verseImage.ts changes in a way
// that should invalidate already-cached cards.
const PROMPT_VERSION = "2026-09-18.1";

// India has a fixed +05:30 offset and no DST, so a plain millisecond shift is
// exact. `index.ts` already hardcodes Asia/Kolkata for recurring events.
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

const MONTHS = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

export type DailyVerseLanguage = "en" | "ta";

export type CachedCard = {
  style: string;
  path: string;
  // Tokenised Firebase download URL, the same kind `getDownloadURL()` returns
  // for feed images. Clients load this directly instead of reading the object
  // through Storage rules — see the 2026-09-23 amendment in
  // KT Files/architecture/daily-verse-card-caching.md. Absent on entries
  // written before that change; `ensureCardUrls` backfills those on read.
  url?: string;
};

export type DailyVerseCacheResult =
  // `images` is present only for the caller that actually generated them:
  // it already has the bytes in hand, so sending them inline saves it a
  // round trip back down from Storage for objects it just uploaded. Every
  // later caller gets paths only and reads them from Storage.
  // `fromDayKey` is set only when the cards served are an earlier day's:
  // today's are missing and a previous day's were shown instead.
  | {
      status: "ready";
      cards: CachedCard[];
      images?: GeneratedCandidate[];
      fromDayKey?: string;
      generationUsed?: boolean;
    }
  | {status: "generating"}
  // Fetch-only callers (members in the For You tab) get this when the
  // church's admin has not generated today's cards yet *and* no earlier day
  // within the fallback window has any either. Members never trigger
  // generation, so there is nothing for them to wait on.
  | {status: "unavailable"; generationUsed?: boolean};

/** What the caller must generate once this module hands it the lock. */
export type GeneratedCandidate = {
  style: string;
  data: string;
  mimeType: string;
};

export type GenerateFn = (inputs: {
  churchName: string;
  contactNumber: string;
  dateLabel: string;
}) => Promise<GeneratedCandidate[]>;

export type DailyVerseRequest = {
  uid: string;
  email: string;
  churchId: string;
  language: DailyVerseLanguage;
  book: string;
  chapter: number;
  verse: number;
  // "fetch" = a member viewing in For You: read the cache, never generate,
  // never spend. "generate" = a church admin pressing Generate images in
  // Studio. Generation is admin-only by design — members must not be able to
  // spend the church's daily cap.
  mode: "fetch" | "generate";
  generate: GenerateFn;
};

/**
 * Today's date in Asia/Kolkata, as `YYYY-MM-DD` plus a human label.
 * @return {{dayKey: string, dateLabel: string}} The church-day key and label.
 */
export function istToday(): {dayKey: string; dateLabel: string} {
  const shifted = new Date(Date.now() + IST_OFFSET_MS);
  const year = shifted.getUTCFullYear();
  const month = shifted.getUTCMonth();
  const day = shifted.getUTCDate();
  const pad = (value: number) => value.toString().padStart(2, "0");
  return {
    dayKey: `${year}-${pad(month + 1)}-${pad(day)}`,
    dateLabel: `${day} ${MONTHS[month]} ${year}`,
  };
}

/**
 * Short, stable digest of everything a cached card's content depends on.
 *
 * Deliberately built from *server-resolved* values only. The client sends the
 * verse reference and text, but the reference is validated against
 * `config/app.dailyVerse` before we get here and it is the config's values
 * that are hashed — so a caller cannot move the cache key, and cannot spend
 * the church's daily cap by varying its own input.
 * @param {string[]} parts Ordered inputs to digest.
 * @return {string} A 12-character hex digest.
 */
function fingerprint(parts: (string | number)[]): string {
  return createHash("sha256")
    .update(JSON.stringify(parts))
    .digest("hex")
    .slice(0, 12);
}

/**
 * Reads a nested string, or "" when absent or the wrong type.
 * @param {unknown} value Raw value.
 * @return {string} The trimmed string, or "".
 */
function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * Throws unless the caller may read this church's cards: an approved member,
 * or one of its admins.
 *
 * Super-admin status alone deliberately does NOT qualify: the three
 * authorities in this app are separate and per-church access must never be
 * inferred from the global one.
 * @param {string} uid The caller's uid.
 * @param {string} email The caller's lowercased email.
 * @param {string} churchId The church being read.
 * @return {Promise<boolean>} True when the caller is a church admin.
 */
async function authorize(
  uid: string,
  email: string,
  churchId: string,
): Promise<boolean> {
  const db = firestoreDb();
  const configSnap = await db
    .collection("churches")
    .doc(churchId)
    .collection("config")
    .doc("app")
    .get();
  const admins = configSnap.data()?.admins;
  // Admin emails are stored as typed, so casing varies ("Ephrim17@..." vs
  // "ephrim17@..."). Both sides are lowercased before comparing — an admin
  // whose entry happens to carry a capital must not be locked out.
  const isAdmin =
    Array.isArray(admins) &&
    !!email &&
    admins.some(
      (entry) => typeof entry === "string" && entry.toLowerCase() === email,
    );
  if (isAdmin) return true;

  const memberSnap = await db
    .collection("churches")
    .doc(churchId)
    .collection("members")
    .doc(uid)
    .get();
  if (memberSnap.data()?.approved === true) return false;

  throw new HttpsError("permission-denied", "not-a-member");
}

/**
 * A tokenised Firebase download URL, the same shape `getDownloadURL()` builds.
 * @param {string} bucket The bucket name.
 * @param {string} path The object path.
 * @param {string} token The object's firebaseStorageDownloadTokens value.
 * @return {string} A URL any client can fetch without Storage rules.
 */
function downloadUrl(bucket: string, path: string, token: string): string {
  return `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/` +
    `${encodeURIComponent(path)}?alt=media&token=${token}`;
}

/**
 * Fills in `url` for cards stored before download tokens were minted.
 *
 * Reuses the object's existing token when it has one and mints one otherwise,
 * so repeated calls converge rather than rotating the URL out from under
 * clients. A card whose object has gone (retention) is returned untouched and
 * simply fails to load, exactly as it did before.
 * @param {CachedCard[]} cards The cards about to be served.
 * @return {Promise<{cards: CachedCard[], changed: boolean}>} Enriched cards,
 * and whether anything needs persisting.
 */
async function ensureCardUrls(
  cards: CachedCard[],
): Promise<{cards: CachedCard[]; changed: boolean}> {
  const bucket = admin.storage().bucket();
  let changed = false;
  const filled = await Promise.all(
    cards.map(async (card) => {
      if (card.url) return card;
      try {
        const file = bucket.file(card.path);
        const [meta] = await file.getMetadata();
        const existing = (meta?.metadata as Record<string, unknown> | undefined)
          ?.firebaseStorageDownloadTokens;
        let token = typeof existing === "string" ? existing.split(",")[0] : "";
        if (!token) {
          token = randomUUID();
          await file.setMetadata({
            metadata: {firebaseStorageDownloadTokens: token},
          });
        }
        changed = true;
        return {...card, url: downloadUrl(bucket.name, card.path, token)};
      } catch (error) {
        logger.warn("Could not build a download URL for a Daily Verse card.", {
          path: card.path,
          error: error instanceof Error ? error.message : String(error),
        });
        return card;
      }
    }),
  );
  return {cards: filled, changed};
}

/**
 * The `count` church-day keys immediately before `dayKey`, most recent first.
 *
 * Pure and exported so the date arithmetic can be checked without Firestore,
 * like [decideLockOutcome]. Day keys are date-only, so plain UTC arithmetic on
 * the parsed value is exact — the IST offset is already baked into `dayKey` by
 * [istToday] and must not be applied twice.
 * @param {string} dayKey Today's church-day key, `YYYY-MM-DD`.
 * @param {number} count How many earlier days to return.
 * @return {string[]} Earlier day keys, newest first.
 */
export function previousDayKeys(dayKey: string, count: number): string[] {
  const [year, month, day] = dayKey.split("-").map(Number);
  const base = Date.UTC(year, month - 1, day);
  const pad = (value: number) => value.toString().padStart(2, "0");
  const keys: string[] = [];
  for (let back = 1; back <= count; back++) {
    const at = new Date(base - back * 24 * 60 * 60 * 1000);
    keys.push(
      `${at.getUTCFullYear()}-${pad(at.getUTCMonth() + 1)}-` +
        `${pad(at.getUTCDate())}`,
    );
  }
  return keys;
}

/**
 * The most recent earlier church-day that has ready cards for a language.
 *
 * Reads the previous [FALLBACK_LOOKBACK_DAYS] day docs by id in one `getAll`
 * rather than an ordered query. `orderBy(documentId(), "desc")` looks like the
 * natural expression of "most recent first", but Firestore rejects it without
 * a composite `__name__ DESC` index, which this project does not have — it
 * fails the whole fetch with FAILED_PRECONDITION, which the client then shows
 * as the same "not created yet" card. Point reads need no index, are bounded
 * at 7, and run only on a miss.
 * @param {admin.firestore.DocumentReference} churchRef The church document.
 * @param {DailyVerseLanguage} language Which language's cards are wanted.
 * @param {string} dayKey Today's church-day key; only days before it match.
 * @return {Promise<{dayKey: string, cards: CachedCard[]} | null>} The cards
 * and the day they were generated for, or null when there are none.
 */
async function findFallbackCards(
  churchRef: admin.firestore.DocumentReference,
  language: DailyVerseLanguage,
  dayKey: string,
): Promise<{dayKey: string; cards: CachedCard[]} | null> {
  const cards = churchRef.collection("dailyVerseCards");
  const refs = previousDayKeys(dayKey, FALLBACK_LOOKBACK_DAYS).map((key) =>
    cards.doc(key),
  );
  // getAll preserves the order the refs were passed in, so this walks the
  // days newest first and stops at the first one with usable cards.
  const snaps = await firestoreDb().getAll(...refs);
  for (const doc of snaps) {
    const languages = (doc.data()?.languages ?? {}) as Record<
      string,
      ExistingEntry
    >;
    const entry = languages[language];
    if (
      entry?.status === "ready" &&
      Array.isArray(entry.cards) &&
      entry.cards.length > 0
    ) {
      return {dayKey: doc.id, cards: entry.cards};
    }
  }
  return null;
}

type LockOutcome =
  | {kind: "hit"; cards: CachedCard[]}
  | {kind: "pending"}
  | {kind: "failed"}
  | {kind: "lock"};

/**
 * Whether this church-day's one generation has already been spent.
 *
 * The product rule is one *successful* generation per church per day: a run
 * that failed, or that only got one language out, leaves the day open so the
 * admin can press again. Both languages `ready` — whatever their fingerprints
 * — means the day is done, which is what disables Studio's button and what
 * stops a verse edit from buying a second paid run.
 *
 * Fingerprints are deliberately not consulted. An admin who changes the verse
 * after a successful run has already spent the day; their new verse's cards
 * are generated tomorrow, and until then members fall back to the most recent
 * day that has cards.
 * @param {Record<string, ExistingEntry>} languages The day's entries.
 * @return {boolean} True when both languages are ready.
 */
export function dailyGenerationUsed(
  languages: Record<string, ExistingEntry>,
): boolean {
  return (["en", "ta"] as const).every(
    (language) => languages[language]?.status === "ready",
  );
}

/**
 * Decides what a caller should do with the cache entry it found.
 *
 * Pulled out of the transaction as a pure function because this is the one
 * piece of logic where a mistake costs real money, and it is far easier to
 * reason about (and, if `functions/` ever gains a test runner, to test) with
 * no Firestore around it. `lock` means "you generate"; every other outcome
 * means "you do not".
 *
 * Note there is no `lock` for a matching entry that is `ready` — that is the
 * whole point of the cache. An entry only re-enters generation when its
 * fingerprint no longer matches (the verse or church details changed), when
 * a `generating` lock has gone stale, or when a `failed` entry's cooldown
 * has elapsed.
 * @param {ExistingEntry | undefined} entry This language's stored entry.
 * @param {string} fp The fingerprint the caller expects.
 * @param {number} now Current epoch milliseconds.
 * @return {LockOutcome | null} The outcome, or null to fall through to the
 * cap check and take the lock.
 */
export function decideLockOutcome(
  entry: ExistingEntry | undefined,
  fp: string,
  now: number,
): LockOutcome | null {
  if (entry?.fingerprint !== fp) return null;
  if (entry.status === "ready" && Array.isArray(entry.cards)) {
    return {kind: "hit", cards: entry.cards};
  }
  if (
    entry.status === "generating" &&
    now - toMillis(entry.startedAt) < LOCK_STALE_MS
  ) {
    return {kind: "pending"};
  }
  if (
    entry.status === "failed" &&
    now - toMillis(entry.failedAt) < FAILURE_COOLDOWN_MS
  ) {
    return {kind: "failed"};
  }
  return null;
}

/**
 * Serves today's cached Daily Verse cards for a church, generating them once
 * if nobody has yet.
 *
 * The first member to ask takes a lock inside a Firestore transaction and
 * generates; everyone after reads what they produced. Concurrent callers see
 * `generating` rather than starting a second paid batch.
 * @param {DailyVerseRequest} request Caller, church, verse and generator.
 * @return {Promise<DailyVerseCacheResult>} Cards, or a generating marker.
 */
export async function getOrCreateDailyVerseCards(
  request: DailyVerseRequest,
): Promise<DailyVerseCacheResult> {
  const {uid, email, churchId, language, generate} = request;
  const db = firestoreDb();

  const isAdmin = await authorize(uid, email, churchId);
  // Generation is the only thing that costs money, and it is now driven by
  // the church's admin from Studio — a member browsing For You must never be
  // able to start a batch.
  if (request.mode === "generate" && !isAdmin) {
    throw new HttpsError("permission-denied", "admin-required");
  }

  const churchRef = db.collection("churches").doc(churchId);
  const [configSnap, churchSnap] = await Promise.all([
    churchRef.collection("config").doc("app").get(),
    churchRef.get(),
  ]);

  const configured = configSnap.data()?.dailyVerse;
  const configuredBook = readString(
    (configured as Record<string, unknown> | undefined)?.book,
  );
  const configuredChapter = Number(
    (configured as Record<string, unknown> | undefined)?.chapter,
  );
  const configuredVerse = Number(
    (configured as Record<string, unknown> | undefined)?.verse,
  );
  if (!configuredBook || !configuredChapter || !configuredVerse) {
    throw new HttpsError("failed-precondition", "no-daily-verse");
  }

  // D5 Option B: the client supplies the rendered text, but the reference it
  // claims must be the church's actual configured Daily Verse. This is what
  // stops a hand-made call from generating an arbitrary card that the whole
  // church then sees, and what keeps the cache key out of the client's reach.
  if (
    request.book !== configuredBook ||
    request.chapter !== configuredChapter ||
    request.verse !== configuredVerse
  ) {
    logger.warn("Daily Verse reference did not match church config.", {
      churchId,
      uid,
      claimed: `${request.book} ${request.chapter}:${request.verse}`,
      configured: `${configuredBook} ${configuredChapter}:${configuredVerse}`,
    });
    throw new HttpsError("failed-precondition", "verse-mismatch");
  }

  const churchName = readString(churchSnap.data()?.name);
  const contactNumber = readString(churchSnap.data()?.contact);
  const {dayKey, dateLabel} = istToday();
  const fp = fingerprint([
    churchId,
    dayKey,
    language,
    configuredBook,
    configuredChapter,
    configuredVerse,
    churchName,
    contactNumber,
    PROMPT_VERSION,
  ]);

  const cacheRef = churchRef.collection("dailyVerseCards").doc(dayKey);
  const cap = parseInt(dailyVerseCardDailyCap.value(), 10) || 4;
  const now = Date.now();

  // Members read without any transaction at all: there is no lock to take
  // and nothing to spend, so a plain get is both cheaper and faster. A
  // fingerprint mismatch here means the admin edited the verse after
  // generating — the stale cards are deliberately not served.
  if (request.mode === "fetch") {
    const snap = await cacheRef.get();
    const languages = (snap.data()?.languages ?? {}) as Record<
      string,
      ExistingEntry
    >;
    const entry = languages[language];
    // Reported on every fetch so Studio can lock its Generate button without
    // reading the cache doc itself. It deliberately does not come from a
    // client-side Firestore read: `storage.rules`/`firestore.rules` compare
    // the caller's lowercased email against `config/app.admins` as stored, so
    // an admin whose entry carries a capital fails `isChurchAdmin`, while
    // `authorize()` above lowercases both sides and gets it right.
    const generationUsed = dailyGenerationUsed(languages);
    if (
      entry?.fingerprint === fp &&
      entry.status === "ready" &&
      Array.isArray(entry.cards) &&
      entry.cards.length > 0
    ) {
      const filled = await ensureCardUrls(entry.cards);
      if (filled.changed) await persistCards(cacheRef, language, filled.cards);
      return {status: "ready", cards: filled.cards, generationUsed};
    }
    // Nothing usable for today: the admin hasn't generated yet, or edited
    // the verse after generating. Rather than leave the card empty, serve
    // the most recent earlier day that does have cards. The fingerprint is
    // deliberately not checked there — an earlier day's entry hashes that
    // day's date and verse, so it can never match today's, and serving it
    // is the whole point.
    const fallback = await findFallbackCards(churchRef, language, dayKey);
    if (fallback) {
      const filled = await ensureCardUrls(fallback.cards);
      if (filled.changed) {
        await persistCards(
          churchRef.collection("dailyVerseCards").doc(fallback.dayKey),
          language,
          filled.cards,
        );
      }
      return {
        status: "ready",
        cards: filled.cards,
        fromDayKey: fallback.dayKey,
        generationUsed,
      };
    }
    return {status: "unavailable", generationUsed};
  }

  const outcome = await db.runTransaction<LockOutcome>(async (tx) => {
    const snap = await tx.get(cacheRef);
    const data = snap.data() ?? {};
    const languages = (data.languages ?? {}) as Record<string, ExistingEntry>;
    const decided = decideLockOutcome(languages[language], fp, now);
    if (decided) return decided;

    // Checked after decideLockOutcome so an already-generated, still-current
    // day stays an idempotent no-op ("hit") rather than an error. Reaching
    // here with both languages ready means the fingerprint moved — the admin
    // edited the verse after today's run — and that must not buy a second one.
    if (dailyGenerationUsed(languages)) {
      throw new HttpsError("failed-precondition", "daily-generation-used");
    }

    const attemptCount = (data.attemptCount as number | undefined) ?? 0;
    if (attemptCount >= cap) {
      throw new HttpsError("resource-exhausted", "church-cap-exceeded");
    }

    const expireAt = new Date(now + 14 * 24 * 60 * 60 * 1000);
    tx.set(
      cacheRef,
      {
        dayKey,
        attemptCount: attemptCount + 1,
        expireAt: admin.firestore.Timestamp.fromDate(expireAt),
        languages: {
          [language]: {
            status: "generating",
            fingerprint: fp,
            startedAt: admin.firestore.Timestamp.fromMillis(now),
            generatedBy: uid,
            cards: [],
            failedAt: null,
          },
        },
      },
      {merge: true},
    );
    return {kind: "lock"};
  });

  if (outcome.kind === "hit") return {status: "ready", cards: outcome.cards};
  if (outcome.kind === "pending") return {status: "generating"};
  if (outcome.kind === "failed") {
    throw new HttpsError("internal", "generation-failed");
  }

  let candidates: GeneratedCandidate[];
  try {
    candidates = await generate({churchName, contactNumber, dateLabel});
  } catch (error) {
    await markFailed(cacheRef, language, error);
    throw error instanceof HttpsError ?
      error :
      new HttpsError("internal", "generation-failed");
  }

  if (candidates.length === 0) {
    await markFailed(cacheRef, language, new Error("no candidates"));
    throw new HttpsError("internal", "generation-failed");
  }

  const bucket = admin.storage().bucket();
  const cards: CachedCard[] = [];
  for (const candidate of candidates) {
    // The fingerprint is part of the object name, so a regeneration writes a
    // new object rather than overwriting bytes a member may be mid-download
    // of. Old objects are left to the retention lifecycle rule.
    const path =
      `dailyVerseCards/${churchId}/${dayKey}/` +
      `${language}-${candidate.style}-${fp}.jpg`;
    // The download token is what makes the object readable by URL, exactly as
    // `getDownloadURL()` does for every other upload in this app. Minted here
    // because the Admin SDK has no getDownloadURL().
    const token = randomUUID();
    await bucket.file(path).save(Buffer.from(candidate.data, "base64"), {
      contentType: candidate.mimeType || "image/jpeg",
      metadata: {
        cacheControl: "private, max-age=86400",
        metadata: {firebaseStorageDownloadTokens: token},
      },
    });
    cards.push({
      style: candidate.style,
      path,
      url: downloadUrl(bucket.name, path, token),
    });
  }

  await cacheRef.set(
    {
      languages: {
        [language]: {
          status: "ready",
          fingerprint: fp,
          cards,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          failedAt: null,
        },
      },
    },
    {merge: true},
  );

  return {status: "ready", cards, images: candidates};
}

type ExistingEntry = {
  status?: string;
  fingerprint?: string;
  cards?: CachedCard[];
  startedAt?: admin.firestore.Timestamp;
  failedAt?: admin.firestore.Timestamp;
};

/**
 * Milliseconds from a Firestore timestamp, or 0 when absent — an absent
 * timestamp reads as "infinitely stale", so a half-written lock can always
 * be taken over rather than blocking the church for the day.
 * @param {admin.firestore.Timestamp | undefined} value The timestamp.
 * @return {number} Epoch milliseconds, or 0.
 */
function toMillis(value?: admin.firestore.Timestamp): number {
  return value?.toMillis?.() ?? 0;
}

/**
 * Writes back cards whose `url` was just backfilled, so the next reader skips
 * the Storage metadata round trip. Best-effort: a failure here costs a repeat
 * backfill, never a failed fetch.
 * @param {admin.firestore.DocumentReference} ref The church-day doc.
 * @param {DailyVerseLanguage} language Which language's entry to update.
 * @param {CachedCard[]} cards The enriched cards.
 * @return {Promise<void>} Resolves once written, or once the failure is logged.
 */
async function persistCards(
  ref: admin.firestore.DocumentReference,
  language: DailyVerseLanguage,
  cards: CachedCard[],
): Promise<void> {
  try {
    await ref.set({languages: {[language]: {cards}}}, {merge: true});
  } catch (error) {
    logger.warn("Could not persist backfilled Daily Verse card URLs.", {
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

/**
 * Records a failed batch so concurrent callers stop waiting on a lock that
 * will never complete, and so the cooldown above can hold off retries.
 * @param {admin.firestore.DocumentReference} ref The church-day doc.
 * @param {DailyVerseLanguage} language Which language failed.
 * @param {unknown} error What went wrong.
 * @return {Promise<void>} Resolves once recorded.
 */
async function markFailed(
  ref: admin.firestore.DocumentReference,
  language: DailyVerseLanguage,
  error: unknown,
): Promise<void> {
  try {
    await ref.set(
      {
        languages: {
          [language]: {
            status: "failed",
            failedAt: admin.firestore.FieldValue.serverTimestamp(),
            failureReason:
              error instanceof Error ? error.message : String(error),
          },
        },
      },
      {merge: true},
    );
  } catch (writeError) {
    logger.error("Failed to record Daily Verse card failure.", {
      error:
        writeError instanceof Error ? writeError.message : String(writeError),
    });
  }
}
