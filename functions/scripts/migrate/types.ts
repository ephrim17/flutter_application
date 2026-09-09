/**
 * Shared types for the user/church decoupling backfill
 * (KT Files/architecture/user-church-decoupling-migration.md, Phase 2).
 */

export interface CliOptions {
  dryRun: boolean;
  databaseId: string;
  /** null = every church. */
  churchIds: string[] | null;
  outDir: string;
  projectId: string;
}

export interface ConflictRow {
  uid: string;
  field: string;
  churchId: string;
  keptValue: string;
  discardedValue: string;
  reason: string;
}

export interface ChurchReport {
  churchId: string;
  churchName: string;
  oldMemberDocCount: number;
  linkedMemberCount: number;
  unlinkedMemberCount: number;
  membershipsWritten: number;
  groupMembersRekeyed: number;
  groupMembersUnresolved: number;
  learningResultsTagged: number;
  learningResultsUnresolved: number;
  readingPlanDocsMoved: number;
  learningProgressGlobalIdsMerged: number;
  learningProgressChurchIdsKept: number;
  learningProgressDroppedIds: number;
  errors: string[];
}

export interface RunReport {
  startedAt: string;
  finishedAt: string;
  dryRun: boolean;
  databaseId: string;
  churchesProcessed: number;
  identitiesWritten: number;
  avatarBlobsMigrated: number;
  churches: ChurchReport[];
  conflictCount: number;
}

/**
 * Builds a zeroed-out report for one church, to be filled in as the
 * migration processes it.
 * @param {string} churchId Church id.
 * @param {string} churchName Church display name.
 * @return {ChurchReport} The zeroed report.
 */
export function emptyChurchReport(
  churchId: string,
  churchName: string,
): ChurchReport {
  return {
    churchId,
    churchName,
    oldMemberDocCount: 0,
    linkedMemberCount: 0,
    unlinkedMemberCount: 0,
    membershipsWritten: 0,
    groupMembersRekeyed: 0,
    groupMembersUnresolved: 0,
    learningResultsTagged: 0,
    learningResultsUnresolved: 0,
    readingPlanDocsMoved: 0,
    learningProgressGlobalIdsMerged: 0,
    learningProgressChurchIdsKept: 0,
    learningProgressDroppedIds: 0,
    errors: [],
  };
}
