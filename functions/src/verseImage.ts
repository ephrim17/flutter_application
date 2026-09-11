import {logger} from "firebase-functions";
import {defineSecret, defineString} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {firestoreDb} from "./firestoreDb";

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const aiImageDailyCap = defineString("AI_IMAGE_DAILY_CAP", {default: "5"});
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
  const cap = parseInt(aiImageDailyCap.value(), 10) || 5;
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
 * the client never controls the raw prompt sent to Gemini.
 * @param {string} verseText The verse's text.
 * @param {string} reference The verse's reference (e.g. "John 3:16").
 * @return {string} The prompt to send to Gemini.
 */
function buildPrompt(verseText: string, reference: string): string {
  const referencePart = reference ? ` (${reference})` : "";
  return "A serene, high-quality background image evoking the mood and " +
    "imagery of this Bible verse, with NO text, letters or words rendered " +
    `in the image: "${verseText}"${referencePart}. Photographic or soft ` +
    "painterly style, calm and reverent, suitable for all audiences.";
}

type GeminiInteractionResponse = {
  output_image?: {
    data?: string;
    mime_type?: string;
  };
};

type GeneratedImage = {
  data: string;
  mimeType: string;
};

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
  const data = payload.output_image?.data;
  if (!data) {
    logger.error("Gemini image generation returned no image.", {payload});
    throw new HttpsError("internal", "generation-failed");
  }
  return {
    data,
    mimeType: payload.output_image?.mime_type ?? "image/png",
  };
}

const candidatesPerRequest = 3;

export const generateVerseBackgroundImage = onCall(
  {region: "us-central1", secrets: [geminiApiKey]},
  async (request) => {
    const uid = readString(request.auth?.uid);
    if (!uid) throw new HttpsError("unauthenticated", "Sign-in required.");

    const verseText = readString(request.data?.verseText);
    if (!verseText) {
      throw new HttpsError("invalid-argument", "Missing verseText.");
    }
    const reference = readString(request.data?.reference);

    // One quota unit covers the whole batch of candidates below — the cap
    // is expressed in user-facing "generate" actions, not raw API calls.
    await reserveDailyQuota(uid);

    const prompt = buildPrompt(verseText, reference);
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
