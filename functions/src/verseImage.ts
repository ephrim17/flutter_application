import {logger} from "firebase-functions";
import {defineSecret, defineString} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {firestoreDb} from "./firestoreDb";

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
 * Today's date key (UTC) for the per-user daily usage counter.
 * @return {string} A YYYY-MM-DD string.
 */
function todayKey(): string {
  return new Date().toISOString().slice(0, 10);
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
 * The top banner instruction shared by every card style: "Praise the Lord"
 * plus today's date in the top-right corner, when known.
 * @param {string} dateLabel Today's date, pre-formatted human-readable
 * (e.g. "12 September 2026") by the client, or "" if not supplied.
 * @return {string} The instruction fragment.
 */
function buildTopInstruction(dateLabel: string): string {
  return " At the very top of the image, add a small " +
    "banner or heading that reads \"Praise the Lord\"" +
    (dateLabel ?
      `, and place today's date, "${dateLabel}", in the top-right ` +
        "corner in a small, human-readable style (already given as day, " +
        "full month name and year — render it exactly as given, not as " +
        "numeric digits-only)." :
      ".");
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
 * @param {string} dateLabel Today's date, pre-formatted human-readable
 * (e.g. "12 September 2026") by the client.
 * @return {string} The prompt to send to Gemini.
 */
function buildBackgroundStylePrompt(
  verseText: string,
  reference: string,
  churchName: string,
  contactNumber: string,
  dateLabel: string,
): string {
  const referencePart = reference ? ` (${reference})` : "";
  const topInstruction = buildTopInstruction(dateLabel);
  const footerInstruction = buildFooterInstruction(churchName, contactNumber);
  return "Design a complete, ready-to-share devotional verse card image, " +
    "in the style of a designed Christian social-media graphic." +
    `${topInstruction} Create a background that evokes the mood and ` +
    "imagery of this Bible verse — photographic or soft painterly style, " +
    "calm and reverent, suitable for all audiences — and render the " +
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
 * @param {string} dateLabel Today's date, pre-formatted human-readable, by
 * the client.
 * @return {string} The prompt to send to Gemini.
 */
function buildInfographicPrompt(
  verseText: string,
  reference: string,
  churchName: string,
  contactNumber: string,
  dateLabel: string,
): string {
  const referencePart = reference ? ` (${reference})` : "";
  const topInstruction = buildTopInstruction(dateLabel);
  const footerInstruction = buildFooterInstruction(churchName, contactNumber);
  return "Design a clean, modern, flat-design infographic-style devotional " +
    "card for this Bible verse — the look of a well-designed social-media " +
    "infographic (flat vector shapes, a soft solid or gently-gradiented " +
    "background, generous whitespace, a clean grid-aligned layout), not a " +
    "photographic or painterly background." +
    `${topInstruction} Render the verse text itself directly and legibly ` +
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
 * circles — a real person against a golden-hour outdoor scene, with the
 * verse broken into short phrases stacked as bold, colorful icon-labeled
 * banner strips (not painted ornamental lettering). Shares the same
 * top-banner and church-branding footer rules as
 * [buildBackgroundStylePrompt]; only the art direction differs.
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
 * @param {string} dateLabel Today's date, pre-formatted human-readable, by
 * the client.
 * @return {string} The prompt to send to Gemini.
 */
function buildDevotionalPosterPrompt(
  verseText: string,
  reference: string,
  churchName: string,
  contactNumber: string,
  dateLabel: string,
): string {
  const referencePart = reference ? ` (${reference})` : "";
  const topInstruction = buildTopInstruction(dateLabel);
  const footerInstruction = buildFooterInstruction(churchName, contactNumber);
  return "Design a vibrant, modern devotional social-media graphic in " +
    "the widely-shared South Indian Christian WhatsApp/Facebook-forward " +
    "style — photographic, energetic and colorful, not painterly or " +
    "muted, not a flat-design infographic." +
    `${topInstruction} On the left side of the image, place a ` +
    "contemporary young Indian man or woman, shown from the chest up in " +
    "three-quarter profile, wearing casual modern clothing, gazing " +
    "upward and outward with a hopeful, faithful expression, holding a " +
    "black Bible with a small cross on its cover clutched close to the " +
    "chest. Behind this person, render a warm golden-hour outdoor " +
    "landscape: green hills and trees, a winding path, a large low sun " +
    "casting golden light and soft lens-glow across a partly-cloudy " +
    "blue sky, and a simple cross silhouette standing on a distant " +
    "hilltop, backlit by the sunrise. Render this person " +
    "photorealistically and with dignity; do not depict any real, " +
    "recognizable or famous individual. Across the right two-thirds of " +
    "the image, break the verse text into its natural short phrases and " +
    "stack them vertically as a sequence of bold, rounded " +
    "highlighter-style banner strips — one phrase per strip, each strip " +
    "a different vivid solid color (blue, green, magenta, teal, purple, " +
    "orange; vary them so no two adjacent strips share a color), each " +
    "paired on its left with a small simple white icon whose meaning " +
    "matches that phrase's own theme (choose icons appropriate to this " +
    "specific verse — for example an open book, a walking figure, a " +
    "heart, a dove, a cross, a shield — based on what each phrase " +
    "itself says). Render every phrase's text in bold white lettering " +
    "with a thin dark outline so it stays legible against its strip's " +
    "color, breaking the verse only at natural phrase boundaries, never " +
    "mid-word. Beneath the phrase strips, add one larger, visually " +
    "distinct banner in a different solid color (e.g. deep navy) " +
    "holding the verse's concluding clause or summary phrase in bold, " +
    "bright-yellow lettering sized larger than the strips above it, so " +
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

type GeminiInteractionResponse = {
  output_image?: {
    data?: string;
    mime_type?: string;
  };
  steps?: InteractionStep[];
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
 * Calls Gemini's image-generation endpoint and returns the raw base64 image
 * bytes plus mime type.
 * @param {string} prompt The prompt to send.
 * @return {Promise<GeneratedImage>} The generated image.
 */
async function callGeminiImageGeneration(
  prompt: string,
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

// Temporary testing carve-out, per direct instruction: unlimited
// generations for this one account while the feature is being tried out
// post-release, bypassing the otherwise-strict 1/day production cap.
// Remove once testing is done.
const unlimitedTestEmail = "ephrim17@gmail.com";

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
    const dateLabel = readString(request.data?.dateLabel);

    // One quota unit covers the whole batch of candidates below — the cap
    // is expressed in user-facing "generate" actions, not raw API calls.
    if (email !== unlimitedTestEmail) {
      await reserveDailyQuota(uid);
    }

    const infographicPrompt = buildInfographicPrompt(
      verseText,
      reference,
      churchName,
      contactNumber,
      dateLabel,
    );
    const devotionalPosterPrompt = buildDevotionalPosterPrompt(
      verseText,
      reference,
      churchName,
      contactNumber,
      dateLabel,
    );
    const backgroundPrompt = buildBackgroundStylePrompt(
      verseText,
      reference,
      churchName,
      contactNumber,
      dateLabel,
    );
    const settled = await Promise.allSettled([
      callGeminiImageGeneration(infographicPrompt),
      callGeminiImageGeneration(devotionalPosterPrompt),
      callGeminiImageGeneration(backgroundPrompt),
    ]);
    const images = settled
      .filter(
        (result): result is PromiseFulfilledResult<GeneratedImage> =>
          result.status === "fulfilled",
      )
      .map((result) => result.value);

    if (images.length === 0) {
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
