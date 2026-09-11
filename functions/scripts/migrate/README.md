# User/church decoupling backfill

Implements Phase 2 of
`KT Files/architecture/user-church-decoupling-migration.md`. Splits each
church's old `churches/{cid}/users/{uid}` rows into a person identity
(`users/{uid}`) and a church membership (`churches/{cid}/members/{uid}`),
merging one person's data across every church they belong to, splits
learning progress by module source (§5.6), tags `learning_results` rows,
moves `readingPlans` onto the identity, and re-keys `groups/{gid}/users` to
`groups/{gid}/groupMembers`.

**Non-destructive.** This only ever writes new paths — it never deletes the
old `churches/{cid}/users` or `groups/{gid}/users` rows. Re-running it is
safe and idempotent: every write is a full `.set()` recomputed from the
current source data, not an incremental merge.

## Credentials

This is a plain Node script, not a deployed Cloud Function, so it needs its
own Google Cloud credentials — a `firebase login` session is not enough.
One-time setup, either:

- `gcloud auth application-default login` (interactive browser login), or
- download a service account key for the project and set
  `GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json`.

Either way, the credential needs Firestore + Firebase Auth read/write access
on the target project.

## Usage

```bash
cd functions
npm run migrate -- --database=migrationv1                # dry run, all churches
npm run migrate -- --database=migrationv1 --church=abc123 # dry run, one church
npm run migrate -- --database=migrationv1 --write         # actually write
```

- `--dry-run` is the default — reads and reports, writes nothing.
- `--write` performs the writes. Refused outright against `--database=(default)`
  — production cutover (Phase 8) is a separate, deliberate step, not this flag.
- `--church=<id>[,<id>...]` limits the run to specific churches. Default: all.
- `--out=<dir>` sets the report directory (default `migration-reports/`).
- `--project=<id>` overrides the Firebase project id (default
  `flutterlearning-c9f6c`).

Each run writes a timestamped JSON report and a conflicts CSV to the output
directory — read both before re-running with `--write`. Per Phase 2's exit
criterion: re-run the dry run until the report stops changing and the
conflicts CSV has been reviewed, *then* run with `--write`.

## What "linked" and "unlinked" mean

For every old row, the script checks whether the row's doc id is a real
Firebase Auth uid (`admin.auth().getUser`):

- **Linked** — a real person with a login. Contributes to that uid's
  identity doc, merged across every church they belong to (newest
  non-empty value wins per field; every discarded value is logged to the
  conflicts CSV).
- **Unlinked** — admin-created, no login (§9.3/§9.4). Keeps its old row id
  as the membership doc id, contributes no identity doc, and its `display*`
  fields stay its own authoritative data rather than a cache.

## Known gap: identity conflict recency

§5.1's conflict rule is "newest `updatedAt` wins" — but the pre-migration
data has no `updatedAt` field, only `createdAt`. This script uses
`createdAt` as the best available recency signal instead. Documented here
and in the migration doc's Phase 2 addendum so it isn't mistaken for an
oversight later.
