import * as admin from "firebase-admin";
import {ConflictRow} from "./types";

/** One church's old `churches/{cid}/users/{oldUid}` row, as read from
 * Firestore (pre-migration `AppUser` shape). */
export interface OldMemberRow {
  churchId: string;
  oldDocId: string;
  data: FirebaseFirestore.DocumentData;
  /** Best available recency signal — the source data has no `updatedAt`,
   * only `createdAt` (§9.5-adjacent gap, not called out in the spec but
   * confirmed absent from the real data). */
  recency: Date;
}

export interface MergedIdentity {
  name: string;
  email: string;
  phone: string;
  profilePhotoUrl: string;
  dob: FirebaseFirestore.Timestamp | null;
  gender: string;
  location: string;
  address: string;
  maritalStatus: string;
  weddingDay: FirebaseFirestore.Timestamp | null;
  educationalQualification: string;
  talentsAndGifts: string[];
  dayStreak: number;
  lastStreakRecordedAt: FirebaseFirestore.Timestamp | null;
  createdAt: FirebaseFirestore.Timestamp;
  profileComplete: boolean;
}

/**
 * Trims a value down to a string, or "" if it isn't one.
 * @param {unknown} value Raw Firestore field value.
 * @return {string} The trimmed string, or "".
 */
function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * Reads a Firestore array field as a list of trimmed, non-empty strings.
 * @param {unknown} value Raw Firestore field value.
 * @return {string[]} The cleaned string list.
 */
function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => asString(item))
    .filter((item) => item.length > 0);
}

/**
 * The old data wrote `dayStreak` as a string in some rows (`toString()`
 * at write time) — coerce to int either way (§9.5).
 * @param {unknown} value Raw Firestore field value.
 * @return {number} The coerced streak count.
 */
function asDayStreak(value: unknown): number {
  if (typeof value === "number") return Math.round(value);
  if (typeof value === "string") {
    const parsed = parseInt(value.trim(), 10);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

/**
 * Reads a Firestore field as a Timestamp, or null if it isn't one.
 * @param {unknown} value Raw Firestore field value.
 * @return {FirebaseFirestore.Timestamp | null} The timestamp, or null.
 */
function asTimestamp(
  value: unknown,
): FirebaseFirestore.Timestamp | null {
  if (value && typeof (value as {toDate?: unknown}).toDate === "function") {
    return value as FirebaseFirestore.Timestamp;
  }
  return null;
}

/**
 * `phone` absorbs `contact` where `phone` is empty (D8), applied per row
 * before cross-row conflict resolution.
 * @param {FirebaseFirestore.DocumentData} data One old row's raw data.
 * @return {string} The merged phone value for this row.
 */
function rowPhone(data: FirebaseFirestore.DocumentData): string {
  const phone = asString(data["phone"]);
  return phone.length > 0 ? phone : asString(data["contact"]);
}

/**
 * Merges every linked row belonging to one person into a single identity,
 * per §5.1/Phase 2: newest (best available recency) wins per field,
 * non-empty beats empty, every discarded non-empty value is logged as a
 * conflict.
 * @param {string} uid The resolved auth uid these rows belong to.
 * @param {OldMemberRow[]} rows Every old row across every church that
 * resolved to this uid.
 * @param {ConflictRow[]} conflicts Conflict rows are appended here as
 * they're found.
 * @return {MergedIdentity} The merged identity ready to write to
 * `users/{uid}`.
 */
export function mergeIdentity(
  uid: string,
  rows: OldMemberRow[],
  conflicts: ConflictRow[],
): MergedIdentity {
  const sorted = [...rows].sort(
    (a, b) => b.recency.getTime() - a.recency.getTime(),
  );

  /**
   * Picks the winning string value for one field across every row, newest
   * non-empty value wins, logging every discarded non-empty value.
   * @param {string} field Field name, for conflict logging.
   * @param {function(OldMemberRow): string} reader Reads the field from a
   * row.
   * @return {string} The winning value, or "" if no row had one.
   */
  function pickString(field: string, reader: (row: OldMemberRow) => string):
    string {
    let winner = "";
    let winnerChurch = "";
    for (const row of sorted) {
      const value = reader(row);
      if (value.length === 0) continue;
      if (winner.length === 0) {
        winner = value;
        winnerChurch = row.churchId;
        continue;
      }
      if (value !== winner) {
        conflicts.push({
          uid,
          field,
          churchId: row.churchId,
          keptValue: `${winner} (from ${winnerChurch})`,
          discardedValue: value,
          reason: "older-or-tied row, non-empty value differs",
        });
      }
    }
    return winner;
  }

  /**
   * Same rule as pickString, for Timestamp-valued fields.
   * @param {string} field Field name, for conflict logging.
   * @param {function(OldMemberRow): (FirebaseFirestore.Timestamp | null)}
   * reader Reads the field from a row.
   * @return {FirebaseFirestore.Timestamp | null} The winning value, or null.
   */
  function pickTimestamp(
    field: string,
    reader: (row: OldMemberRow) => FirebaseFirestore.Timestamp | null,
  ): FirebaseFirestore.Timestamp | null {
    let winner: FirebaseFirestore.Timestamp | null = null;
    let winnerChurch = "";
    for (const row of sorted) {
      const value = reader(row);
      if (!value) continue;
      if (!winner) {
        winner = value;
        winnerChurch = row.churchId;
        continue;
      }
      if (!value.isEqual(winner)) {
        conflicts.push({
          uid,
          field,
          churchId: row.churchId,
          keptValue: `${winner.toDate().toISOString()} (from ${winnerChurch})`,
          discardedValue: value.toDate().toISOString(),
          reason: "older-or-tied row, non-empty value differs",
        });
      }
    }
    return winner;
  }

  const name = pickString("name", (row) => asString(row.data["name"]));
  const email = pickString(
    "email", (row) => asString(row.data["email"]).toLowerCase(),
  );
  const phone = pickString("phone", (row) => rowPhone(row.data));
  const profilePhotoUrl = pickString(
    "profilePhotoUrl", (row) => asString(row.data["profilePhotoUrl"]),
  );
  const gender = pickString("gender", (row) => asString(row.data["gender"]));
  const location =
    pickString("location", (row) => asString(row.data["location"]));
  const address =
    pickString("address", (row) => asString(row.data["address"]));
  const maritalStatus = pickString(
    "maritalStatus", (row) => asString(row.data["maritalStatus"]),
  );
  const educationalQualification = pickString(
    "educationalQualification",
    (row) => asString(row.data["educationalQualification"]),
  );

  const dob = pickTimestamp("dob", (row) => asTimestamp(row.data["dob"]));
  const weddingDay = pickTimestamp(
    "weddingDay", (row) => asTimestamp(row.data["weddingDay"]),
  );

  // talentsAndGifts: union rather than winner-take-all — losing someone's
  // recorded talent because a newer row happened to list fewer isn't the
  // same kind of conflict as a contradicted scalar field.
  const talentsAndGifts = Array.from(new Set(
    sorted.flatMap((row) => asStringArray(row.data["talentsAndGifts"])),
  ));

  // dayStreak: collapse to the max across churches, keeping the
  // lastStreakRecordedAt of whichever row achieved it (Phase 2 bullet).
  let dayStreak = 0;
  let lastStreakRecordedAt: FirebaseFirestore.Timestamp | null = null;
  for (const row of sorted) {
    const streak = asDayStreak(row.data["dayStreak"]);
    if (streak > dayStreak) {
      dayStreak = streak;
      lastStreakRecordedAt = asTimestamp(row.data["lastStreakRecordedAt"]);
    }
  }

  const earliestCreatedAt = sorted.reduce<FirebaseFirestore.Timestamp | null>(
    (earliest, row) => {
      const createdAt = asTimestamp(row.data["createdAt"]);
      if (!createdAt) return earliest;
      if (!earliest || createdAt.toMillis() < earliest.toMillis()) {
        return createdAt;
      }
      return earliest;
    },
    null,
  );

  const profileComplete =
    location.length > 0 && address.length > 0 && maritalStatus.length > 0;

  return {
    name,
    email,
    phone,
    profilePhotoUrl,
    dob,
    gender,
    location,
    address,
    maritalStatus,
    weddingDay,
    educationalQualification,
    talentsAndGifts,
    dayStreak,
    lastStreakRecordedAt,
    createdAt: earliestCreatedAt ??
      admin.firestore.Timestamp.fromDate(sorted[0].recency),
    profileComplete,
  };
}
