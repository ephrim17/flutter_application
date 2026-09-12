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
const geminiImageModel = "gemini-3.1-flash-image";

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
 * Builds a fixed, moderation-friendly prompt from the verse text/reference —
 * the client never controls the raw prompt sent to Gemini. Asks for a
 * complete, ready-to-share devotional card: a top banner ("Praise the
 * Lord" + date), the verse text itself (in its original script) rendered
 * directly into the image, and a decorative church banner (full name in
 * bold capitals, "For prayer" callout, phone number) at the bottom — not
 * just an abstract background.
 * @param {string} verseText The verse's text.
 * @param {string} reference The verse's reference (e.g. "John 3:16").
 * @param {string} churchName The church's full display name, if known.
 * @param {string} contactNumber The church's contact phone number, if known.
 * @param {string} dateLabel Today's date, pre-formatted human-readable
 * (e.g. "12 September 2026") by the client.
 * @return {string} The prompt to send to Gemini.
 */
function buildPrompt(
  verseText: string,
  reference: string,
  churchName: string,
  contactNumber: string,
  dateLabel: string,
): string {
  const referencePart = reference ? ` (${reference})` : "";

  const topInstruction = " At the very top of the image, add a small " +
    "banner or heading that reads \"Praise the Lord\"" +
    (dateLabel ?
      `, and place today's date, "${dateLabel}", in the top-right ` +
        "corner in a small, human-readable style (already given as day, " +
        "full month name and year — render it exactly as given, not as " +
        "numeric digits-only)." :
      ".");

  let footerInstruction = "";
  if (churchName || contactNumber) {
    // Uppercased here (not left to the model) so it's guaranteed correct
    // regardless of how well the prompt's styling instruction is followed.
    const namePart = churchName ?
      `"${churchName.toUpperCase()}"` :
      "the church's name";
    const phonePart = contactNumber ?
      ` and a phone icon next to the number "${contactNumber}"` :
      "";
    footerInstruction = " At the very bottom of the image, design a " +
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
    `"${verseText}"${referencePart}.${footerInstruction} Keep all text ` +
    "sharp, legible and well-contrasted against the background.";
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
  const response = await fetch(geminiInteractionsUrl, {
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
  });
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

const candidatesPerRequest = 3;

// Temporary testing carve-out, per direct instruction: unlimited
// generations for this one account while the feature is being tried out
// post-release, bypassing the otherwise-strict 1/day production cap.
// Remove once testing is done.
const unlimitedTestEmail = "ephrim17@gmail.com";

export const generateVerseBackgroundImage = onCall(
  {region: "us-central1", secrets: [geminiApiKey]},
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

    const prompt = buildPrompt(
      verseText,
      reference,
      churchName,
      contactNumber,
      dateLabel,
    );
    const settled = await Promise.allSettled(
      Array.from({length: candidatesPerRequest}, () =>
        callGeminiImageGeneration(prompt)),
    );
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
