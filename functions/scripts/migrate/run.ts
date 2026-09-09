#!/usr/bin/env node
import * as admin from "firebase-admin";
import {getFirestore} from "firebase-admin/firestore";
import {parseCliOptions} from "./cli";
import {runMigration} from "./migrate";
import {writeReport} from "./report";

/* eslint-disable no-console */
/**
 * CLI entrypoint: parses flags, runs the migration, writes the report.
 * @return {Promise<void>} Resolves once the run and report are complete.
 */
async function main(): Promise<void> {
  const options = parseCliOptions(process.argv.slice(2));

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: options.projectId,
    storageBucket: `${options.projectId}.firebasestorage.app`,
  });
  const firestore = getFirestore(admin.app(), options.databaseId);
  const auth = admin.auth();
  const storage = admin.storage();

  console.log(
    `Running migration: database=${options.databaseId} ` +
    `mode=${options.dryRun ? "DRY-RUN" : "WRITE"} ` +
    `churches=${options.churchIds?.join(",") ?? "ALL"}`,
  );

  const {report, conflicts} =
    await runMigration(firestore, auth, storage, options);
  const {reportPath, conflictsPath} =
    writeReport(options.outDir, report, conflicts);

  console.log(`\nChurches processed: ${report.churchesProcessed}`);
  console.log(`Identities ${report.dryRun ? "that would be " : ""}written: ` +
    `${report.identitiesWritten}`);
  console.log(
    `Avatar blobs ${report.dryRun ? "that would be " : ""}migrated: ` +
    `${report.avatarBlobsMigrated}`,
  );
  for (const church of report.churches) {
    console.log(
      `  - ${church.churchName} (${church.churchId}): ` +
      `${church.oldMemberDocCount} members ` +
      `(${church.linkedMemberCount} linked, ` +
      `${church.unlinkedMemberCount} unlinked), ` +
      `${church.membershipsWritten} memberships, ` +
      `${church.groupMembersRekeyed} group members rekeyed ` +
      `(${church.groupMembersUnresolved} unresolved), ` +
      `${church.learningResultsTagged} results tagged ` +
      `(${church.learningResultsUnresolved} unresolved), ` +
      `${church.readingPlanDocsMoved} reading plan docs moved, ` +
      `${church.learningProgressGlobalIdsMerged} global progress ids ` +
      `merged, ${church.learningProgressDroppedIds} progress ids dropped` +
      (church.errors.length > 0 ?
        ` -- ERRORS: ${church.errors.join("; ")}` :
        ""),
    );
  }
  console.log(`\nConflicts logged: ${report.conflictCount}`);
  console.log(`Report: ${reportPath}`);
  console.log(`Conflicts CSV: ${conflictsPath}`);
  if (report.dryRun) {
    console.log(
      "\nThis was a dry run — nothing was written. Re-run with --write " +
      "once the report and conflicts CSV look right.",
    );
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
