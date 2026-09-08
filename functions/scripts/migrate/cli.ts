import {CliOptions} from "./types";

const defaultProjectId = "flutterlearning-c9f6c";

/**
 * Parses the migration harness CLI flags. Defaults are deliberately the
 * safe ones: `--dry-run` unless `--write` is passed explicitly, and no
 * default database — you must name one, so a bare invocation can never
 * silently touch production.
 * @param {string[]} argv Raw CLI arguments (without the node/script path
 * entries).
 * @return {CliOptions} Parsed options.
 */
export function parseCliOptions(argv: string[]): CliOptions {
  let dryRun = true;
  let databaseId: string | null = null;
  let churchIds: string[] | null = null;
  let outDir = "migration-reports";
  let projectId = defaultProjectId;

  for (const arg of argv) {
    if (arg === "--write") {
      dryRun = false;
    } else if (arg === "--dry-run") {
      dryRun = true;
    } else if (arg.startsWith("--database=")) {
      databaseId = arg.slice("--database=".length).trim();
    } else if (arg.startsWith("--church=")) {
      const value = arg.slice("--church=".length).trim();
      churchIds = value
        .split(",")
        .map((id) => id.trim())
        .filter((id) => id.length > 0);
    } else if (arg.startsWith("--out=")) {
      outDir = arg.slice("--out=".length).trim();
    } else if (arg.startsWith("--project=")) {
      projectId = arg.slice("--project=".length).trim();
    } else if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unrecognized argument: ${arg}. Run with --help.`);
    }
  }

  if (!databaseId) {
    throw new Error(
      "Missing --database=<id>. There is no default — you must name the " +
      "target database explicitly (e.g. --database=migrationv1) so a bare " +
      "invocation can never touch production by accident.",
    );
  }
  if (databaseId === "(default)" && dryRun === false) {
    throw new Error(
      "Refusing to --write against the (default) database. This harness " +
      "is for migrating into a copy (e.g. migrationv1); production " +
      "cutover is Phase 8, run manually and deliberately, not through " +
      "this flag.",
    );
  }

  return {dryRun, databaseId, churchIds, outDir, projectId};
}

/** Prints CLI usage to stdout. */
function printHelp(): void {
  // eslint-disable-next-line no-console
  console.log(`
User/church decoupling backfill (Phase 2).

Usage:
  npm run migrate -- --database=<id> [--church=<id>[,<id>...]] \\
    [--write] [--out=<dir>]

Flags:
  --database=<id>   Required. Target Firestore database (e.g. migrationv1).
                     Refuses --write against "(default)".
  --church=<id,...> Optional. Limit to specific church ids. Default: all.
  --dry-run         Default. Reads and reports; writes nothing.
  --write           Actually perform the writes described by the dry-run.
  --out=<dir>       Report output directory. Default: migration-reports.
  --project=<id>    Firebase project id. Default: ${defaultProjectId}.
`);
}
