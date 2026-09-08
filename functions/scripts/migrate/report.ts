import * as fs from "fs";
import * as path from "path";
import {ConflictRow, RunReport} from "./types";

/**
 * Escapes a value for inclusion in a CSV cell.
 * @param {string} value Raw cell value.
 * @return {string} The CSV-safe value.
 */
function csvEscape(value: string): string {
  if (/[",\n]/.test(value)) {
    return `"${value.replace(/"/g, "\"\"")}"`;
  }
  return value;
}

/**
 * Writes the JSON run report and the conflicts CSV to `outDir`, timestamped
 * so successive dry runs don't clobber each other.
 * @param {string} outDir Directory to write into (created if missing).
 * @param {RunReport} report The run report.
 * @param {ConflictRow[]} conflicts Every conflict found during identity
 * merging.
 * @return {{reportPath: string, conflictsPath: string}} The two file paths
 * written.
 */
export function writeReport(
  outDir: string,
  report: RunReport,
  conflicts: ConflictRow[],
): {reportPath: string; conflictsPath: string} {
  fs.mkdirSync(outDir, {recursive: true});
  const stamp = report.startedAt.replace(/[:.]/g, "-");
  const reportPath = path.join(outDir, `run-${stamp}.json`);
  const conflictsPath = path.join(outDir, `conflicts-${stamp}.csv`);

  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

  const header = "uid,field,churchId,keptValue,discardedValue,reason";
  const rows = conflicts.map((row) => [
    row.uid, row.field, row.churchId, row.keptValue, row.discardedValue,
    row.reason,
  ].map(csvEscape).join(","));
  fs.writeFileSync(conflictsPath, [header, ...rows].join("\n") + "\n");

  return {reportPath, conflictsPath};
}
