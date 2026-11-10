#!/usr/bin/env node
import * as admin from "firebase-admin";
import {getFirestore, Firestore} from "firebase-admin/firestore";

/* eslint-disable no-console */

/**
 * Audits — and optionally repairs — the denormalized
 * `reactionSummary` / `reactionTotal` on every feed post, by recounting the
 * post's own `reactions` subcollection.
 *
 * Why this exists: `recomputeReactionAggregate` used to write the aggregate
 * with `{merge: true}`, which deep-merges map fields. Writing a fresh
 * summary over a stored one therefore only ever *added* emoji keys — when
 * the last person using an emoji removed their reaction, that emoji's key
 * stayed behind at its old count. `reactionTotal` is a scalar and always
 * overwrote correctly, so the signature of the bug is a summary whose
 * counts don't add up to the total. The function now writes with
 * `mergeFields`, which replaces each named field wholesale; this script
 * cleans up posts that drifted before that fix.
 *
 * Safe by default: audits and prints, writing nothing unless `--write` is
 * passed. A post only gets written when its stored aggregate actually
 * disagrees with its reaction docs.
 *
 * Usage:
 *   npm --prefix functions run repair:reactions
 *   npm --prefix functions run repair:reactions -- --write
 *   npm --prefix functions run repair:reactions -- --database=migrationv1
 */

const defaultProjectId = "flutterlearning-c9f6c";

interface Options {
  dryRun: boolean;
  projectId: string;
  databaseId: string;
}

/**
 * Parses this script's CLI flags.
 * @param {string[]} argv Raw arguments, without the node/script entries.
 * @return {Options} Parsed options, defaulting to a dry run.
 */
function parseOptions(argv: string[]): Options {
  let dryRun = true;
  let projectId = defaultProjectId;
  let databaseId = "(default)";

  for (const arg of argv) {
    if (arg === "--write") {
      dryRun = false;
    } else if (arg === "--dry-run") {
      dryRun = true;
    } else if (arg.startsWith("--project=")) {
      projectId = arg.slice("--project=".length).trim();
    } else if (arg.startsWith("--database=")) {
      databaseId = arg.slice("--database=".length).trim();
    } else if (arg === "--help" || arg === "-h") {
      console.log(
        "Audit/repair feed reaction aggregates.\n\n" +
        "  --write              apply fixes (default: audit only)\n" +
        "  --database=<id>      Firestore database (default: (default))\n" +
        "  --project=<id>       GCP project (default: " +
        `${defaultProjectId})\n`,
      );
      process.exit(0);
    } else {
      throw new Error(`Unrecognized argument: ${arg}. Run with --help.`);
    }
  }

  return {dryRun, projectId, databaseId};
}

/**
 * Counts reactions per emoji from a post's `reactions` subcollection.
 * @param {FirebaseFirestore.QuerySnapshot} snapshot The reaction docs.
 * @return {Record<string, number>} Emoji counts, blank emoji ignored.
 */
function countReactions(
  snapshot: FirebaseFirestore.QuerySnapshot,
): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const doc of snapshot.docs) {
    const emoji = doc.data()["emoji"];
    if (typeof emoji !== "string" || !emoji) continue;
    counts[emoji] = (counts[emoji] ?? 0) + 1;
  }
  return counts;
}

/**
 * True when a stored aggregate already matches the counted reactions.
 * @param {Record<string, number>} stored The post's `reactionSummary`.
 * @param {number} storedTotal The post's `reactionTotal`.
 * @param {Record<string, number>} actual Counts from the subcollection.
 * @param {number} actualTotal Number of reaction docs.
 * @return {boolean} Whether the two agree exactly.
 */
function agrees(
  stored: Record<string, number>,
  storedTotal: number,
  actual: Record<string, number>,
  actualTotal: number,
): boolean {
  if (storedTotal !== actualTotal) return false;
  const storedKeys = Object.keys(stored).filter((key) => stored[key] > 0);
  const actualKeys = Object.keys(actual);
  if (storedKeys.length !== actualKeys.length) return false;
  return actualKeys.every((key) => stored[key] === actual[key]);
}

/**
 * Audits one post and, unless this is a dry run, rewrites a drifted
 * aggregate.
 * @param {FirebaseFirestore.QueryDocumentSnapshot} post The post document.
 * @param {boolean} dryRun Whether to write.
 * @return {Promise<boolean>} Whether the post had drifted.
 */
async function auditPost(
  post: FirebaseFirestore.QueryDocumentSnapshot,
  dryRun: boolean,
): Promise<boolean> {
  const reactions = await post.ref.collection("reactions").get();
  const actual = countReactions(reactions);
  const stored = (post.data()["reactionSummary"] ?? {}) as
    Record<string, number>;
  const storedTotal = Number(post.data()["reactionTotal"] ?? 0);

  if (agrees(stored, storedTotal, actual, reactions.size)) return false;

  console.log(
    `  DRIFT ${post.ref.path}\n` +
    `        stored  = ${JSON.stringify(stored)} total=${storedTotal}\n` +
    `        counted = ${JSON.stringify(actual)} total=${reactions.size}`,
  );

  if (!dryRun) {
    await post.ref.set(
      {reactionSummary: actual, reactionTotal: reactions.size},
      {mergeFields: ["reactionSummary", "reactionTotal"]},
    );
    console.log("        repaired.");
  }
  return true;
}

/**
 * Walks every church feed and the global feed.
 * @param {Firestore} db The Firestore instance.
 * @param {boolean} dryRun Whether to write.
 * @return {Promise<{checked: number, drifted: number}>} Run totals.
 */
async function run(
  db: Firestore,
  dryRun: boolean,
): Promise<{checked: number; drifted: number}> {
  let checked = 0;
  let drifted = 0;

  const churches = await db.collection("churches").listDocuments();
  for (const church of churches) {
    const posts = await church.collection("feeds").get();
    for (const post of posts.docs) {
      checked++;
      if (await auditPost(post, dryRun)) drifted++;
    }
  }

  const globalPosts = await db.collection("globalFeeds").get();
  for (const post of globalPosts.docs) {
    checked++;
    if (await auditPost(post, dryRun)) drifted++;
  }

  return {checked, drifted};
}

/**
 * CLI entrypoint.
 * @return {Promise<void>} Resolves once the run is complete.
 */
async function main(): Promise<void> {
  const options = parseOptions(process.argv.slice(2));

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: options.projectId,
  });
  const db = getFirestore(admin.app(), options.databaseId);

  console.log(
    `Reaction aggregate ${options.dryRun ? "audit" : "repair"}: ` +
    `project=${options.projectId} database=${options.databaseId}`,
  );

  const {checked, drifted} = await run(db, options.dryRun);

  console.log(
    `\nChecked ${checked} posts, ${drifted} drifted` +
    (options.dryRun && drifted > 0 ?
      " — re-run with --write to repair." :
      "."),
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
