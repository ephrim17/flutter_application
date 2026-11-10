import 'package:flutter_application/church_app/models/attendance_service_model.dart';

/// How many recent services the average is taken over.
const int attendanceAverageWindow = 8;

/// How many consecutive services someone must miss before they are surfaced
/// as worth a call. Three is deliberately not one: a single absence is a
/// Sunday away, three in a row is a pattern.
const int attendanceAbsenceStreak = 3;

/// The headline numbers above the service list.
class AttendanceSummary {
  const AttendanceSummary({
    required this.lastServicePresent,
    required this.averagePresent,
    required this.lastServicePercent,
    required this.absentIds,
  });

  /// Members marked present at the most recent service, or null when no
  /// service has been recorded yet.
  final int? lastServicePresent;

  /// Mean members present over the last [attendanceAverageWindow] services,
  /// or null when nothing is recorded.
  final int? averagePresent;

  /// [lastServicePresent] as a percentage of the active roster, or null when
  /// there is no service or nobody on the roster to divide by.
  final int? lastServicePercent;

  /// Active members absent from every one of the last
  /// [attendanceAbsenceStreak] services. Empty until that many services
  /// exist — you cannot miss three services that never happened.
  final List<String> absentIds;

  int get absentCount => absentIds.length;

  bool get isEmpty => lastServicePresent == null;
}

/// Services newest first. Ties on date break on id so the ordering is stable
/// across rebuilds — two services on one date must not swap places.
List<AttendanceService> sortAttendanceServices(
  Iterable<AttendanceService> services,
) {
  final sorted = services.toList()
    ..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
  return sorted;
}

/// Computes the four headline numbers.
///
/// [activeMemberIds] is the roster the percentage and the absence streak are
/// measured against — people who are expected, not everyone who ever
/// attended. A visitor marked present therefore raises the head count but
/// can never push the percentage over 100, and never appears in
/// [AttendanceSummary.absentIds].
AttendanceSummary attendanceSummary({
  required Iterable<AttendanceService> services,
  required Set<String> activeMemberIds,
}) {
  final sorted = sortAttendanceServices(services);
  if (sorted.isEmpty) {
    return const AttendanceSummary(
      lastServicePresent: null,
      averagePresent: null,
      lastServicePercent: null,
      absentIds: <String>[],
    );
  }

  final last = sorted.first;
  final lastPresent = last.present.length;

  final window = sorted.take(attendanceAverageWindow).toList(growable: false);
  final average =
      (window.fold<int>(0, (sum, s) => sum + s.present.length) / window.length)
          .round();

  // Only roster members count towards the percentage. Someone marked
  // present who is not on the roster — an unapproved record, a guest added
  // later — raises the head count but must never be able to push
  // "of active members" past 100%.
  final lastPresentOnRoster =
      last.present.where(activeMemberIds.contains).length;
  final percent = activeMemberIds.isEmpty
      ? null
      : (lastPresentOnRoster / activeMemberIds.length * 100).round();

  final streak = sorted.take(attendanceAbsenceStreak).toList(growable: false);
  final absent = streak.length < attendanceAbsenceStreak
      ? const <String>[]
      : (activeMemberIds
          .where(
            (id) => streak.every((service) => !service.present.contains(id)),
          )
          .toList(growable: false)
        ..sort());

  return AttendanceSummary(
    lastServicePresent: lastPresent,
    averagePresent: average,
    lastServicePercent: percent,
    absentIds: absent,
  );
}

/// The ids to mark when one person is tapped with household check-in on:
/// them, plus everyone sharing their family.
///
/// A blank [familyId] means "not in a family", which is the default for most
/// records — it must never be treated as a family that everyone without one
/// belongs to, or tapping one unlinked person would mark the whole church.
Set<String> attendanceHouseholdIds({
  required String memberId,
  required String familyId,
  required Map<String, String> familyIdByMemberId,
}) {
  final household = <String>{memberId};
  final family = familyId.trim();
  if (family.isEmpty) return household;

  for (final entry in familyIdByMemberId.entries) {
    if (entry.value.trim() == family) household.add(entry.key);
  }
  return household;
}

/// Bars for the trend chart, oldest on the left — the reading order of a
/// timeline, and the opposite of the list below it, which is newest first.
List<AttendanceService> attendanceTrendServices(
  Iterable<AttendanceService> services, {
  int limit = 12,
}) {
  return sortAttendanceServices(services)
      .take(limit)
      .toList(growable: false)
      .reversed
      .toList(growable: false);
}
