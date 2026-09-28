import {logger} from "firebase-functions";
import {defineSecret, defineString} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {firestoreDb} from "./firestoreDb";
import {getOrCreateDailyVerseCards, istToday} from "./dailyVerseCache";

const geminiApiKey = defineSecret("GEMINI_API_KEY");
// Product policy: strictly 1 "generate" action per user per day in
// production — each action still returns up to 3 candidates. Overridable
// per-environment via AI_IMAGE_DAILY_CAP (see functions/.env.example).
const aiImageDailyCap = defineString("AI_IMAGE_DAILY_CAP", {default: "1"});
const geminiInteractionsUrl =
  "https://generativelanguage.googleapis.com/v1beta/interactions";
// Pro tier over Flash specifically for its materially better text/spelling
// accuracy (documented ~94% character-level accuracy vs. Flash's weaker
// long-text rendering) — this feature bakes verse text/reference/church
// name directly into the image, so text fidelity matters more here than
// raw speed. Watch generation latency against the 90s per-call abort /
// 180s function timeout below if this tier proves meaningfully slower.
const geminiImageModel = "gemini-3-pro-image";

/**
 * Reads a value as a trimmed string, or "" if it isn't one.
 * @param {unknown} value Raw value.
 * @return {string} The trimmed string, or "".
 */
function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * Today's date key for the per-user daily usage counter — the Asia/Kolkata
 * church-day, so the cap resets at 12am IST for everyone, the same moment
 * Studio's Daily Verse generation unlocks.
 * @return {string} A YYYY-MM-DD string.
 */
function todayKey(): string {
  return istToday().dayKey;
}

/**
 * Atomically checks and increments `users/{uid}/aiUsage/{today}.count`.
 * Throws a `resource-exhausted` HttpsError once the daily cap is reached —
 * checked *before* calling Gemini so a request that would exceed the cap
 * never spends API cost.
 * @param {string} uid The signed-in user's uid.
 * @return {Promise<void>} Resolves once the counter is incremented.
 */
async function reserveDailyQuota(uid: string): Promise<void> {
  const cap = parseInt(aiImageDailyCap.value(), 10) || 1;
  const usageRef = firestoreDb()
    .collection("users")
    .doc(uid)
    .collection("aiUsage")
    .doc(todayKey());
  await firestoreDb().runTransaction(async (tx) => {
    const snapshot = await tx.get(usageRef);
    const count = (snapshot.data()?.count as number | undefined) ?? 0;
    if (count >= cap) {
      throw new HttpsError("resource-exhausted", "quota-exceeded");
    }
    tx.set(
      usageRef,
      {
        count: count + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });
}

/**
 * Returns a unit reserved by [reserveDailyQuota] when the whole batch failed.
 *
 * The reservation happens *before* any Gemini call so a request that would
 * exceed the cap never spends API cost — but that also meant a total failure
 * (all candidates errored, or Gemini was down) burned the user's entire daily
 * allowance and handed them an error for it. Only a total failure refunds: a
 * partial success still delivered cards, so it still costs a unit.
 *
 * Floored at 0 rather than using `FieldValue.increment(-1)`, so a double
 * refund (a retry racing the first call) can never push the counter negative
 * and hand out free generations for the rest of the day.
 * @param {string} uid The signed-in user's uid.
 * @return {Promise<void>} Resolves once the counter is decremented.
 */
async function refundDailyQuota(uid: string): Promise<void> {
  const usageRef = firestoreDb()
    .collection("users")
    .doc(uid)
    .collection("aiUsage")
    .doc(todayKey());
  try {
    await firestoreDb().runTransaction(async (tx) => {
      const snapshot = await tx.get(usageRef);
      const count = (snapshot.data()?.count as number | undefined) ?? 0;
      if (count <= 0) return;
      tx.set(
        usageRef,
        {
          count: count - 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    });
  } catch (error) {
    // The caller is already on its way to throwing `generation-failed`; a
    // failed refund must not replace that with a confusing Firestore error.
    logger.error("Failed to refund AI image quota.", {
      uid,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

/**
 * The top banner instruction shared by every card style: "Praise the Lord".
 *
 * Deliberately dateless. Cards used to carry the generation date in the
 * top-right corner, which made every card wrong the moment it outlived the
 * day it was made for — and the Daily Verse card is now explicitly allowed to
 * outlive it, since a church with no images for today falls back to the most
 * recent day that has them. A dateless card is reusable; a dated one contra-
 * dicts itself.
 * @return {string} The instruction fragment.
 */
function buildTopInstruction(): string {
  return " At the very top of the image, add a small " +
    "banner or heading that reads \"Praise the Lord\".";
}

/**
 * The bottom church-banner instruction shared by every card style: the
 * church's name/contact when known, or an explicit no-branding instruction
 * when there's no church in context (see [buildBackgroundStylePrompt] for
 * why the negative instruction is spelled out rather than just omitted).
 * @param {string} churchName The church's full display name, or "".
 * @param {string} contactNumber The church's contact phone number, or "".
 * @return {string} The instruction fragment.
 */
function buildFooterInstruction(
  churchName: string,
  contactNumber: string,
): string {
  if (!churchName && !contactNumber) {
    return " This card has no church affiliation — do not " +
      "invent or render any church name, ministry name, contact number, " +
      "phone icon, \"for prayer\" banner, or any other church-branding " +
      "element anywhere in the image. Keep the image strictly to the top " +
      "banner and verse text described above, for an individual's " +
      "personal use.";
  }
  // Uppercased here (not left to the model) so it's guaranteed correct
  // regardless of how well the prompt's styling instruction is followed.
  const namePart = churchName ?
    `"${churchName.toUpperCase()}"` :
    "the church's name";
  const phonePart = contactNumber ?
    ` and a phone icon next to the number "${contactNumber}"` :
    "";
  return " At the very bottom of the image, design a " +
    "decorative banner strip like a hand-painted signboard: a bold, " +
    "all-capital-letters rendering (already given in capitals below — " +
    "keep it exactly as given, do not lowercase any of it) of the " +
    "church's full name, exactly and completely as written, with no " +
    `words shortened, abbreviated, cut off or dropped: ${namePart}. ` +
    "Size this name's text to fit the banner's width at full length — " +
    "shrink the font size or wrap it onto two lines if it's long, " +
    "rather than truncating, clipping, or letting it overflow the " +
    "banner's edges. Beneath the name, add a small contrasting-color " +
    "ribbon or ribbon-shaped highlight reading " +
    `"For prayer"${phonePart}. Keep this banner visually secondary to ` +
    "the verse text above it — smaller scale, at the bottom edge only.";
}

/**
 * The spelling-accuracy instruction shared by every card style's closing
 * sentence. Previously each style ended with its own slightly different
 * "keep text sharp/legible" sentence, and only the devotional-poster style
 * said "correctly spelled" — confirmed live that this wasn't strong enough:
 * Gemini's baked-in text rendering has produced garbled Tamil-script
 * references and garbled short phrases even in English. Spelled out
 * explicitly and identically across all three styles now.
 * @return {string} The instruction fragment.
 */
function buildSpellingInstruction(): string {
  return " Every letter of every word of every piece of text in this " +
    "image — the verse, the reference, the church banner, the date — " +
    "must be spelled correctly and match the given text exactly: " +
    "proofread each word before finalizing the image rather than " +
    "approximating unfamiliar letterforms or scripts, and keep all text " +
    "sharp, legible and well-contrasted against its background.";
}

/**
 * The shared art-direction instruction that forces every style's imagery to
 * follow *this* verse rather than generic Christian stock imagery. Confirmed
 * live that without it the model anchors on the prompt's own example imagery:
 * Genesis 23:2 ("Sarah died... and Abraham came to mourn for her, and to
 * weep for her") still produced a smiling person holding a Bible under a
 * golden sunrise, because the devotional-poster prompt described that scene
 * literally. Scene, people, setting, light and palette are all stated here as
 * derived-from-the-verse, with the generic sunrise/Bible/cross imagery called
 * out as an explicit anti-pattern.
 * @return {string} The instruction fragment.
 */
function buildVerseSceneInstruction(): string {
  return " Before designing anything, read the verse text given below and " +
    "work out what it is actually about: who is in it, where and when it " +
    "happens, what is happening, and its emotional register (grief, " +
    "lament, repentance, fear, warning, longing, joy, praise, " +
    "thanksgiving, promise, instruction). Every visual choice — the " +
    "scene, any people and what they are doing, the setting, the time of " +
    "day, the weather, the lighting and the color palette — must follow " +
    "from that reading of this specific verse. A verse of mourning, " +
    "death, lament or repentance must look somber and subdued (fading or " +
    "overcast light, muted desaturated colors, quiet restrained posture); " +
    "a verse of praise, promise or deliverance may look bright and warm. " +
    "Never fall back on generic Christian stock imagery that ignores the " +
    "verse: do not depict anyone holding, opening or reading a Bible " +
    "unless the verse itself speaks about Scripture, and do not add a " +
    "sunrise, a cross on a hilltop, praying hands or a dove merely as " +
    "decoration when this verse's own content points somewhere else. " +
    "Keep the depiction reverent, dignified and suitable for all " +
    "audiences: convey sorrow, death, judgement or conflict through mood, " +
    "posture, distance and light rather than anything graphic, gory or " +
    "frightening, and do not depict any real, recognizable or famous " +
    "living individual.";
}

/**
 * Builds a fixed, moderation-friendly prompt from the verse text/reference —
 * the client never controls the raw prompt sent to Gemini. Asks for a
 * complete, ready-to-share devotional card: a top banner ("Praise the
 * Lord" + date) and the verse text itself (in its original script)
 * rendered directly into the image, over a background matching the
 * verse's mood. When a church is known, also asks for a decorative church
 * banner (full name in bold capitals, "For prayer" callout, phone number)
 * at the bottom; when it isn't (e.g. a guest with no selected church),
 * explicitly tells the model not to invent one.
 * @param {string} verseText The verse's text.
 * @param {string} reference The verse's reference (e.g. "John 3:16").
 * @param {string} churchName The church's full display name, or "" if
 * there's no church in context (e.g. a guest sharing from Favourites).
 * @param {string} contactNumber The church's contact phone number, or ""
 * under the same condition as churchName.
 * @return {string} The prompt to send to Gemini.
 */
function buildBackgroundStylePrompt(
  verseText: string,
  reference: string,
  churchName: string,
  contactNumber: string,
): string {
  const referencePart = reference ? ` (${reference})` : "";
  const topInstruction = buildTopInstruction();
  const footerInstruction = buildFooterInstruction(churchName, contactNumber);
  return "Design a complete, ready-to-share devotional verse card image, " +
    "in the style of a designed Christian social-media graphic." +
    `${topInstruction}${buildVerseSceneInstruction()} Create a background ` +
    "that depicts the scene, imagery and mood of this Bible verse — " +
    "photographic or soft painterly style — and render the " +
    "verse text itself directly and legibly onto the image, in its " +
    "original script and language, exactly as written, positioned " +
    "wherever best suits the composition (below the top banner, center, " +
    "or bottom) given its length. Use engaging, decorative typography: " +
    "give the most important words or phrases their own accent color " +
    "and bold weight, and underline or highlight key phrases with a " +
    "thin colored stroke beneath them, the way a hand-designed " +
    "devotional graphic would — based on what the verse itself emphasizes: " +
    `"${verseText}"${referencePart}.${footerInstruction}` +
    buildSpellingInstruction();
}

/**
 * Builds the infographic-style variant: a flat-design, icon-and-callout
 * layout instead of a photographic/painterly background — the same top
 * "Praise the Lord" banner and church-branding footer rules as
 * [buildBackgroundStylePrompt], but the verse itself is treated as the
 * centerpiece of a clean, scannable infographic rather than overlaid on
 * mood imagery.
 * @param {string} verseText The verse's text.
 * @param {string} reference The verse's reference (e.g. "John 3:16").
 * @param {string} churchName The church's full display name, or "" if
 * there's no church in context.
 * @param {string} contactNumber The church's contact phone number, or ""
 * under the same condition as churchName.
 * @return {string} The prompt to send to Gemini.
 */
function buildInfographicPrompt(
  verseText: string,
  reference: string,
  churchName: string,
  contactNumber: string,
): string {
  const referencePart = reference ? ` (${reference})` : "";
  const topInstruction = buildTopInstruction();
  const footerInstruction = buildFooterInstruction(churchName, contactNumber);
  return "Design a clean, modern, flat-design infographic-style devotional " +
    "card for this Bible verse — the look of a well-designed social-media " +
    "infographic (flat vector shapes, a soft solid or gently-gradiented " +
    "background, generous whitespace, a clean grid-aligned layout), not a " +
    "photographic or painterly background." +
    `${topInstruction}${buildVerseSceneInstruction()}` +
    " Within that flat design language, let the background color, the " +
    "accent colors and any illustrated shapes carry this verse's own mood " +
    "and subject. Render the verse text itself directly and legibly " +
    "onto the image, in its original script and language, exactly as " +
    "written, as the large, bold visual centerpiece of the card. Beneath " +
    "or around the verse text, add 2 to 3 small flat-icon-plus-short-label " +
    "callouts (a simple flat icon paired with a short label). For each " +
    "label, use a short verbatim word or phrase lifted directly, letter " +
    "for letter, from the verse text itself — do not compose, paraphrase " +
    "or invent new wording for the labels, only quote fragments that " +
    "already appear in the verse below, choosing whichever 2 to 3 " +
    "fragments best represent the verse's key theme, encouragement or " +
    "the action it calls for — the way a well-made infographic presents " +
    `a few scannable visual points instead of paragraphs: "${verseText}"` +
    `${referencePart}.${footerInstruction}` +
    buildSpellingInstruction() +
    " Keep the whole composition tidy and grid-aligned rather than busy.";
}

/**
 * Builds the devotional-poster variant: the vibrant, photographic
 * "WhatsApp-forward" devotional graphic common in South Indian Christian
 * circles — a person on the left against an outdoor scene, with the
 * verse broken into short phrases stacked as bold, colorful icon-labeled
 * banner strips (not painted ornamental lettering). Shares the same
 * top-banner and church-branding footer rules as
 * [buildBackgroundStylePrompt]; only the art direction differs.
 *
 * The layout is fixed, but the figure, scene and palette inside it are
 * verse-derived (see [buildVerseSceneInstruction]) — the golden-hour
 * hills/cross-hilltop scene this style used to describe unconditionally is
 * now only the fallback for verses that depict no scene of their own.
 *
 * Deliberately asks for no church logo: the model would invent a
 * plausible-but-wrong emblem for a real, named ministry. The church's
 * name reaches the card through [buildFooterInstruction] instead.
 * @param {string} verseText The verse's text.
 * @param {string} reference The verse's reference (e.g. "John 3:16").
 * @param {string} churchName The church's full display name, or "" if
 * there's no church in context.
 * @param {string} contactNumber The church's contact phone number, or ""
 * under the same condition as churchName.
 * @return {string} The prompt to send to Gemini.
 */
function buildDevotionalPosterPrompt(
  verseText: string,
  reference: string,
  churchName: string,
  contactNumber: string,
): string {
  const referencePart = reference ? ` (${reference})` : "";
  const topInstruction = buildTopInstruction();
  const footerInstruction = buildFooterInstruction(churchName, contactNumber);
  return "Design a vibrant, modern devotional social-media graphic in " +
    "the widely-shared South Indian Christian WhatsApp/Facebook-forward " +
    "style — photographic, energetic and colorful, not painterly or " +
    "muted, not a flat-design infographic." +
    `${topInstruction}${buildVerseSceneInstruction()} On the left side of ` +
    "the image, place a single photorealistic human figure, shown from " +
    "the chest up in three-quarter profile, whose age, clothing, posture, " +
    "gaze and facial expression are drawn from this verse: either the " +
    "person the verse itself is about, or a present-day South Indian " +
    "believer living out what the verse says. If the verse describes " +
    "grief, weeping or repentance, this figure must show that — head " +
    "bowed or turned away, eyes lowered, hands empty or covering the " +
    "face, subdued clothing — not a hopeful upward gaze. Give the figure " +
    "an object to hold only if the verse itself puts one there. Behind " +
    "this person, render an outdoor setting, time of day, weather and " +
    "light taken from the verse's own scene and mood — the place the " +
    "verse names or implies, in the era it describes, lit to match its " +
    "emotional register. Only when the verse describes no scene of its " +
    "own (a bare promise, proverb or instruction) fall back to a warm " +
    "golden-hour landscape of green hills, a winding path and a distant " +
    "cross-topped hilltop. Render this person photorealistically and " +
    "with dignity. Across the right two-thirds of " +
    "the image, break the verse text into its natural short phrases and " +
    "stack them vertically as a sequence of bold, rounded " +
    "highlighter-style banner strips — one phrase per strip, each strip " +
    "a different solid color drawn from a palette that suits the verse's " +
    "emotional register (vivid blue, green, magenta, teal, purple and " +
    "orange for joy, praise, promise or encouragement; deeper, quieter " +
    "tones such as slate, indigo, deep plum and muted teal for grief, " +
    "lament, repentance or warning), varied so no two adjacent strips " +
    "share a color, each " +
    "paired on its left with a small simple white icon whose meaning " +
    "matches what that phrase itself says — pick each icon from the " +
    "phrase's own words (a place, an action, a person, an object or an " +
    "emotion it names) rather than from a stock set of religious symbols; " +
    "an icon of a book, dove or cross belongs there only if that phrase " +
    "is about Scripture, the Spirit or the cross. " +
    "Render every phrase's text in bold white lettering " +
    "with a thin dark outline so it stays legible against its strip's " +
    "color, breaking the verse only at natural phrase boundaries, never " +
    "mid-word. Beneath the phrase strips, add one larger, visually " +
    "distinct banner in a different solid color (e.g. deep navy) " +
    "holding the verse's concluding clause or summary phrase in bold " +
    "lettering, in whichever high-contrast color best suits the palette " +
    "chosen above (bright yellow on a deep tone, for instance), sized " +
    "larger than the strips above it, so " +
    "it reads as the verse's main takeaway. Below that banner, place " +
    "the verse reference inside a small rounded pill, flanked on both " +
    "sides by a small decorative leaf or olive-branch flourish. Render " +
    "every phrase exactly as written, in its original script and " +
    `language: "${verseText}"${referencePart}.${footerInstruction}` +
    buildSpellingInstruction();
}

type InteractionContentBlock = {
  type?: string;
  data?: string;
  mime_type?: string;
};

type InteractionStep = {
  type?: string;
  content?: InteractionContentBlock[];
};

// The interactions endpoint's usage field isn't documented under a single
// stable name, so both spellings are accepted and whichever is present is
// logged verbatim — see [logUsage].
type GeminiUsage = Record<string, unknown>;

type GeminiInteractionResponse = {
  output_image?: {
    data?: string;
    mime_type?: string;
  };
  steps?: InteractionStep[];
  usage?: GeminiUsage;
  usage_metadata?: GeminiUsage;
  usageMetadata?: GeminiUsage;
};

type GeneratedImage = {
  data: string;
  mimeType: string;
};

/**
 * Finds the generated image inside a completed interaction response.
 * Prefers the documented `output_image` convenience field; falls back to
 * scanning `steps` for a model-output image content block, since the raw
 * REST payload's exact shape isn't fully documented and either form may
 * appear depending on the request.
 * @param {GeminiInteractionResponse} payload The parsed response body.
 * @return {GeneratedImage | null} The image, or null if none was found.
 */
function extractGeneratedImage(
  payload: GeminiInteractionResponse,
): GeneratedImage | null {
  if (payload.output_image?.data) {
    return {
      data: payload.output_image.data,
      mimeType: payload.output_image.mime_type ?? "image/jpeg",
    };
  }
  for (const step of payload.steps ?? []) {
    for (const block of step.content ?? []) {
      if (block.type === "image" && block.data) {
        return {data: block.data, mimeType: block.mime_type ?? "image/jpeg"};
      }
    }
  }
  return null;
}

/**
 * Logs whatever token-usage block the response carried.
 *
 * Image output is billed per image at a known rate, but this model also
 * bills its *thinking* tokens, and that share has never been measured here
 * because the response was discarded. Logging it verbatim — rather than
 * picking fields out of it — means the log stays useful if the endpoint
 * renames or extends the block.
 * @param {string} style Which style prompt this call generated.
 * @param {GeminiInteractionResponse} payload The parsed response body.
 * @return {void}
 */
function logUsage(style: string, payload: GeminiInteractionResponse): void {
  const usage =
    payload.usage ?? payload.usage_metadata ?? payload.usageMetadata;
  if (!usage) {
    logger.info("Gemini image generation reported no usage block.", {style});
    return;
  }
  logger.info("Gemini image generation usage.", {style, usage});
}

/**
 * Calls Gemini's image-generation endpoint and returns the raw base64 image
 * bytes plus mime type.
 * @param {string} prompt The prompt to send.
 * @param {string} style Which style prompt this is, for usage logging.
 * @return {Promise<GeneratedImage>} The generated image.
 */
async function callGeminiImageGeneration(
  prompt: string,
  style: string,
): Promise<GeneratedImage> {
  // A single hung Gemini call must not be allowed to block the whole
  // Promise.allSettled batch (and, transitively, the function's own
  // execution deadline) indefinitely — bound each call individually so a
  // slow candidate can fail on its own and let the other candidates still
  // come back within the function's overall timeout.
  const controller = new AbortController();
  const abortTimer = setTimeout(() => controller.abort(), 90_000);
  let response: Response;
  try {
    response = await fetch(geminiInteractionsUrl, {
      method: "POST",
      headers: {
        "x-goog-api-key": geminiApiKey.value(),
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: geminiImageModel,
        input: [{type: "text", text: prompt}],
        response_format: {
          type: "image",
          mime_type: "image/jpeg",
          aspect_ratio: "1:1",
        },
      }),
      signal: controller.signal,
    });
  } catch (error) {
    logger.error("Gemini image generation request failed or timed out.", {
      error: error instanceof Error ? error.message : String(error),
    });
    throw new HttpsError("internal", "generation-failed");
  } finally {
    clearTimeout(abortTimer);
  }
  if (!response.ok) {
    const body = await response.text().catch(() => "");
    logger.error("Gemini image generation HTTP error.", {
      status: response.status,
      body,
    });
    throw new HttpsError("internal", "generation-failed");
  }
  const payload = await response.json() as GeminiInteractionResponse;
  logUsage(style, payload);
  const image = extractGeneratedImage(payload);
  if (!image) {
    logger.error("Gemini image generation returned no image.", {payload});
    throw new HttpsError("internal", "generation-failed");
  }
  return image;
}

// Product decision: 3 candidates per generate action, but not 3 identical
// rolls of the same prompt — one card in each of the three distinct
// styles (infographic, devotional poster, mood background), so the
// swipeable picker offers a real choice of look rather than three random
// variations of one design.

/**
 * Serves the church's shared Daily Verse cards, generating them once per
 * church per day per language.
 *
 * The church name, contact number and date label are resolved server-side
 * inside [getOrCreateDailyVerseCards] and passed back here, so nothing the
 * client sent can shape what the whole church sees. The verse reference the
 * client claims is validated against the church's configured Daily Verse
 * before any generation happens.
 * @param {object} args Caller identity, verse strings and the raw
 * `dailyVerse` argument from the request.
 * @return {Promise<object>} `{status, cards}` for the client.
 */
async function handleDailyVerse(args: {
  uid: string;
  email: string;
  verseText: string;
  reference: string;
  dailyVerse: Record<string, unknown>;
}): Promise<{
  status: string;
  cards?: {style: string; path: string; url?: string}[];
  images?: {data: string; mimeType: string}[];
  fromDayKey?: string;
  generationUsed?: boolean;
}> {
  const churchId = readString(args.dailyVerse.churchId);
  if (!churchId) {
    throw new HttpsError("invalid-argument", "Missing churchId.");
  }
  const language = readString(args.dailyVerse.language) === "en" ? "en" : "ta";
  const mode =
    readString(args.dailyVerse.mode) === "generate" ? "generate" : "fetch";
  const book = readString(args.dailyVerse.book);
  const chapter = Number(args.dailyVerse.chapter);
  const verse = Number(args.dailyVerse.verse);
  if (!book || !chapter || !verse) {
    throw new HttpsError("invalid-argument", "Missing verse reference.");
  }

  const result = await getOrCreateDailyVerseCards({
    uid: args.uid,
    email: args.email,
    churchId,
    language,
    book,
    chapter,
    verse,
    mode,
    generate: async ({churchName, contactNumber}) => {
      const settled = await Promise.allSettled([
        callGeminiImageGeneration(
          buildInfographicPrompt(
            args.verseText,
            args.reference,
            churchName,
            contactNumber,
          ),
          "infographic",
        ),
        callGeminiImageGeneration(
          buildDevotionalPosterPrompt(
            args.verseText,
            args.reference,
            churchName,
            contactNumber,
          ),
          "devotionalPoster",
        ),
        callGeminiImageGeneration(
          buildBackgroundStylePrompt(
            args.verseText,
            args.reference,
            churchName,
            contactNumber,
          ),
          "moodBackground",
        ),
      ]);
      const styles = ["infographic", "devotionalPoster", "moodBackground"];
      return settled.flatMap((outcome, index) =>
        outcome.status === "fulfilled" ?
          [{
            style: styles[index],
            data: outcome.value.data,
            mimeType: outcome.value.mimeType,
          }] :
          [],
      );
    },
  });

  if (result.status !== "ready") {
    return {
      status: result.status,
      generationUsed: "generationUsed" in result ?
        result.generationUsed :
        undefined,
    };
  }
  return {
    status: "ready",
    cards: result.cards,
    // Present only when today's cards were missing and an earlier day's are
    // being served instead — the client shows them either way.
    fromDayKey: result.fromDayKey,
    // Whether this church's one generation for today is spent; Studio locks
    // its Generate button on this.
    generationUsed: result.generationUsed,
    images: result.images?.map((image) => ({
      data: image.data,
      mimeType: image.mimeType,
    })),
  };
}

export const generateVerseBackgroundImage = onCall(
  // 3 image-generation candidates run in parallel below, each individually
  // bounded to 90s (see callGeminiImageGeneration) — 180s gives the whole
  // batch room to complete even if every candidate takes close to its own
  // cap, comfortably above the v2 default (60s), which a live test found
  // was cutting the request off mid-flight.
  {region: "us-central1", secrets: [geminiApiKey], timeoutSeconds: 180},
  async (request) => {
    const uid = readString(request.auth?.uid);
    if (!uid) throw new HttpsError("unauthenticated", "Sign-in required.");
    const email = readString(request.auth?.token.email).toLowerCase();

    const verseText = readString(request.data?.verseText);
    if (!verseText) {
      throw new HttpsError("invalid-argument", "Missing verseText.");
    }
    const reference = readString(request.data?.reference);
    const churchName = readString(request.data?.churchName);
    const contactNumber = readString(request.data?.contactNumber);

    // The Daily Verse path caches per church: the same verse and church
    // banner for every member, so one member's generation serves everyone
    // and the church pays once a day instead of once a member. Everything
    // else (the Bible reader's long-press, Favourites) is an arbitrary
    // user-chosen verse that cannot be shared, so it stays on the per-user
    // quota below, unchanged.
    // See KT Files/architecture/daily-verse-card-caching.md.
    const dailyVerse = request.data?.dailyVerse as
      | Record<string, unknown>
      | undefined;
    if (dailyVerse) {
      return await handleDailyVerse({
        uid,
        email,
        verseText,
        reference,
        dailyVerse,
      });
    }

    // One quota unit covers the whole batch of candidates below — the cap
    // is expressed in user-facing "generate" actions, not raw API calls.
    await reserveDailyQuota(uid);

    const infographicPrompt = buildInfographicPrompt(
      verseText,
      reference,
      churchName,
      contactNumber,
    );
    const devotionalPosterPrompt = buildDevotionalPosterPrompt(
      verseText,
      reference,
      churchName,
      contactNumber,
    );
    const backgroundPrompt = buildBackgroundStylePrompt(
      verseText,
      reference,
      churchName,
      contactNumber,
    );
    const settled = await Promise.allSettled([
      callGeminiImageGeneration(infographicPrompt, "infographic"),
      callGeminiImageGeneration(devotionalPosterPrompt, "devotionalPoster"),
      callGeminiImageGeneration(backgroundPrompt, "moodBackground"),
    ]);
    const images = settled
      .filter(
        (result): result is PromiseFulfilledResult<GeneratedImage> =>
          result.status === "fulfilled",
      )
      .map((result) => result.value);

    if (images.length === 0) {
      // Nothing was delivered, so the reserved unit is given back — the user
      // would otherwise lose their whole day to a transient Gemini outage.
      await refundDailyQuota(uid);
      throw new HttpsError("internal", "generation-failed");
    }

    return {
      images: images.map((image) => ({
        data: image.data,
        mimeType: image.mimeType,
      })),
    };
  },
);
