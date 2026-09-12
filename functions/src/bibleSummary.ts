import {logger} from "firebase-functions";
import {defineSecret, defineString} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {firestoreDb} from "./firestoreDb";

const geminiApiKey = defineSecret("GEMINI_API_KEY");
// Product policy: 1 chapter summary and 5 verse summaries per user per UTC
// day in production. Overridable per-environment (see functions/.env.example).
const bibleChapterSummaryDailyCap = defineString(
  "BIBLE_CHAPTER_SUMMARY_DAILY_CAP",
  {default: "1"},
);
const bibleVerseSummaryDailyCap = defineString(
  "BIBLE_VERSE_SUMMARY_DAILY_CAP",
  {default: "5"},
);
const geminiInteractionsUrl =
  "https://generativelanguage.googleapis.com/v1beta/interactions";
const geminiTextModel = "gemini-3.8-flash";

// Temporary testing carve-out, per direct instruction: unlimited chapter
// and verse summaries for this one account while the feature is being
// tried out post-release, bypassing the otherwise-strict daily caps.
// Remove once testing is done.
const unlimitedTestEmail = "ephrim17@gmail.com";

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
 * Atomically checks and increments the mode-specific counter field inside
 * `users/{uid}/bibleSummaryUsage/{today}` (`chapterCount` or
 * `verseCount`) against its own daily cap. Throws a `resource-exhausted`
 * HttpsError once that cap is reached — checked *before* calling Gemini so
 * a request that would exceed the cap never spends API cost. Skipped
 * entirely for `unlimitedTestEmail`.
 * @param {string} uid The signed-in user's uid.
 * @param {"chapter" | "verse"} mode Which daily cap to check/increment.
 * @return {Promise<void>} Resolves once the counter is incremented.
 */
async function reserveDailyQuota(
  uid: string,
  mode: "chapter" | "verse",
): Promise<void> {
  const field = mode === "chapter" ? "chapterCount" : "verseCount";
  const cap = mode === "chapter" ?
    parseInt(bibleChapterSummaryDailyCap.value(), 10) || 1 :
    parseInt(bibleVerseSummaryDailyCap.value(), 10) || 5;
  const usageRef = firestoreDb()
    .collection("users")
    .doc(uid)
    .collection("bibleSummaryUsage")
    .doc(todayKey());
  await firestoreDb().runTransaction(async (tx) => {
    const snapshot = await tx.get(usageRef);
    const count = (snapshot.data()?.[field] as number | undefined) ?? 0;
    if (count >= cap) {
      throw new HttpsError("resource-exhausted", "quota-exceeded");
    }
    tx.set(
      usageRef,
      {
        [field]: count + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });
}

/**
 * Builds a fixed, moderation-friendly prompt — the client sends only the
 * raw Scripture text/reference, never a free-form prompt. Asks Gemini to
 * act as a warm, simple Bible-study tutor and return strictly-structured
 * bilingual JSON so the two languages can be reliably split apart on the
 * client.
 * @param {"chapter" | "verse"} mode Whether this is a whole chapter or one
 * verse.
 * @param {string} tamilText The passage's Tamil text.
 * @param {string} englishText The passage's English text.
 * @param {string} reference The passage's reference (e.g. "Genesis 1:1" or
 * "Genesis 1").
 * @return {string} The prompt to send to Gemini.
 */
function buildSummaryPrompt(
  mode: "chapter" | "verse",
  tamilText: string,
  englishText: string,
  reference: string,
): string {
  const scopeLabel = mode === "chapter" ? "Bible chapter" : "Bible verse";
  const bulletCount = mode === "chapter" ? "4-6" : "2-3";
  return "You are a warm, clear Bible study tutor helping a church " +
    `member understand a ${scopeLabel} (${reference}). Explain it in ` +
    "simple, everyday language a new believer could follow, warm and " +
    "encouraging in tone, not a scholarly or academic analysis, and " +
    "never inventing details not implied by the text.\n\n" +
    `Tamil text: "${tamilText}"\n` +
    `English text: "${englishText}"\n\n` +
    "Format your explanation as clean, simple bullet points someone " +
    `can glance at quickly — ${bulletCount} bullets, each one a single ` +
    "short sentence or phrase, no sub-bullets, no headings. Start each " +
    "bullet line with \"• \". Separate bullets with a newline character.\n\n" +
    "Respond with ONLY a single JSON object, no markdown code fences and " +
    "no text outside the JSON, with exactly two keys: \"tamil\" (the " +
    "bulleted explanation written entirely in the Tamil script) and " +
    "\"english\" (the bulleted explanation written entirely in English). " +
    "Each value should stand on its own — do not just translate one into " +
    "the other, write both naturally in that language.";
}

type InteractionContentBlock = {
  type?: string;
  text?: string;
};

type InteractionStep = {
  type?: string;
  content?: InteractionContentBlock[];
};

type GeminiInteractionResponse = {
  output_text?: string;
  steps?: InteractionStep[];
};

/**
 * Finds the generated text inside a completed interaction response.
 * Prefers the documented `output_text` convenience field; falls back to
 * scanning `steps` for a model-output text content block, since the raw
 * REST payload's exact shape isn't fully documented and either form may
 * appear depending on the request.
 * @param {GeminiInteractionResponse} payload The parsed response body.
 * @return {string | null} The text, or null if none was found.
 */
function extractGeneratedText(
  payload: GeminiInteractionResponse,
): string | null {
  if (payload.output_text) return payload.output_text;
  for (const step of payload.steps ?? []) {
    for (const block of step.content ?? []) {
      if (block.type === "text" && block.text) return block.text;
    }
  }
  return null;
}

/**
 * Calls Gemini's text-generation endpoint and returns the raw text.
 * @param {string} prompt The prompt to send.
 * @return {Promise<string>} The generated text.
 */
async function callGeminiTextGeneration(prompt: string): Promise<string> {
  const response = await fetch(geminiInteractionsUrl, {
    method: "POST",
    headers: {
      "x-goog-api-key": geminiApiKey.value(),
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: geminiTextModel,
      input: [{type: "text", text: prompt}],
    }),
  });
  if (!response.ok) {
    const body = await response.text().catch(() => "");
    logger.error("Gemini text generation HTTP error.", {
      status: response.status,
      body,
    });
    throw new HttpsError("internal", "generation-failed");
  }
  const payload = await response.json() as GeminiInteractionResponse;
  const text = extractGeneratedText(payload);
  if (!text) {
    logger.error("Gemini text generation returned no text.", {payload});
    throw new HttpsError("internal", "generation-failed");
  }
  return text;
}

type BilingualSummary = {
  tamil: string;
  english: string;
};

/**
 * Parses the model's JSON-object response into the two-language shape,
 * stripping a markdown code fence first if the model added one despite
 * being asked not to.
 * @param {string} rawText The model's raw output text.
 * @return {BilingualSummary} The parsed bilingual summary.
 */
function parseBilingualSummary(rawText: string): BilingualSummary {
  const stripped = rawText
    .trim()
    .replace(/^```(?:json)?/i, "")
    .replace(/```$/, "")
    .trim();
  try {
    const parsed = JSON.parse(stripped) as Partial<BilingualSummary>;
    if (typeof parsed.tamil === "string" &&
        typeof parsed.english === "string") {
      return {tamil: parsed.tamil, english: parsed.english};
    }
  } catch (error) {
    logger.error("Failed to parse bilingual summary JSON.", {
      rawText,
      error: error instanceof Error ? error.message : String(error),
    });
  }
  // Defensive fallback: surface whatever text came back rather than
  // failing outright, so a formatting slip doesn't lose real content.
  return {tamil: "", english: stripped};
}

export const summarizeBibleContent = onCall(
  {region: "us-central1", secrets: [geminiApiKey]},
  async (request) => {
    const uid = readString(request.auth?.uid);
    if (!uid) throw new HttpsError("unauthenticated", "Sign-in required.");
    const email = readString(request.auth?.token.email).toLowerCase();

    const modeRaw = readString(request.data?.mode);
    const mode = modeRaw === "chapter" ? "chapter" : "verse";
    const tamilText = readString(request.data?.tamilText);
    const englishText = readString(request.data?.englishText);
    if (!tamilText && !englishText) {
      throw new HttpsError("invalid-argument", "Missing passage text.");
    }
    const reference = readString(request.data?.reference);

    if (email !== unlimitedTestEmail) {
      await reserveDailyQuota(uid, mode);
    }

    const prompt = buildSummaryPrompt(mode, tamilText, englishText, reference);
    const rawText = await callGeminiTextGeneration(prompt);
    const summary = parseBilingualSummary(rawText);

    return {tamil: summary.tamil, english: summary.english};
  },
);
