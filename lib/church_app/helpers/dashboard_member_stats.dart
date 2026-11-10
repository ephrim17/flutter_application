/// Member-composition maths for the dashboard's member snapshot.
///
/// These are pure groupings of the member list the dashboard already loads,
/// computed on the client rather than read from the precomputed
/// `dashboard_metrics/members` document.
///
/// Why they moved here: a stored aggregate is a second answer to a question
/// the client can already answer, and the two can disagree. They did — the
/// Cloud Function's adapter never mapped `displayGender`, so every church's
/// gender view read "Unknown, 100%" while the drill-down screen, which
/// filters this same list, stayed correct. Deriving from the list on screen
/// removes that whole class of bug: there is nothing to go stale, nothing to
/// backfill, and changing a bucket definition is no longer a deploy.
///
/// The streak numbers deliberately stay server-side: they read `dayStreak`
/// from `users/{uid}`, which the rules only expose to that user themselves,
/// so no client can aggregate them.
///
/// Bucket **ids** are stable keys, never display text. Labels are localized
/// at render time from `dashboard.*_bucket.<id>`, and colours are keyed off
/// the id — the previous code switched on the English label, which quietly
/// made every segment grey in any other language.
library;

import 'package:flutter_application/church_app/models/church_membership_model.dart';

/// One segment of a member-snapshot chart.
class DashboardMemberBucket {
  const DashboardMemberBucket({
    required this.id,
    required this.count,
  });

  /// A stable key such as `male`, `seniors`, `not_solemnized`.
  final String id;

  /// How many members fall in this segment. The snapshot shows counts and
  /// shares only — no view lists the members themselves.
  final int count;
}

/// Plain headline counts for the overview row.
class DashboardMemberCounts {
  const DashboardMemberCounts({
    required this.memberCount,
    required this.approvedMembers,
    required this.pendingApprovals,
    required this.familyCount,
    required this.individualCount,
    required this.membersWithGroups,
    required this.groupParticipationRate,
  });

  static const empty = DashboardMemberCounts(
    memberCount: 0,
    approvedMembers: 0,
    pendingApprovals: 0,
    familyCount: 0,
    individualCount: 0,
    membersWithGroups: 0,
    groupParticipationRate: 0,
  );

  final int memberCount;
  final int approvedMembers;
  final int pendingApprovals;
  final int familyCount;
  final int individualCount;
  final int membersWithGroups;
  final int groupParticipationRate;
}

/// Age in whole years on today's date, or null when no date of birth is on
/// file. Null is not zero: "we don't know" and "a newborn" are different
/// answers and must land in different buckets.
int? dashboardMemberAge(DateTime? dob, {DateTime? asOf}) {
  if (dob == null) return null;
  final now = asOf ?? DateTime.now();
  var age = now.year - dob.year;
  final hadBirthday = now.month > dob.month ||
      (now.month == dob.month && now.day >= dob.day);
  if (!hadBirthday) age -= 1;
  return age < 0 ? null : age;
}

String _normalized(String value) => value.trim().toLowerCase();

List<DashboardMemberBucket> _bucketBy(
  List<ChurchMembership> members,
  Map<String, bool Function(ChurchMembership)> matchers,
) {
  final buckets = <DashboardMemberBucket>[];
  for (final entry in matchers.entries) {
    final matched = members.where(entry.value).length;
    // An empty bucket is not drawn — a 0% segment is noise, and "Female: 0"
    // reads as a finding rather than an absence.
    if (matched == 0) continue;
    buckets.add(DashboardMemberBucket(id: entry.key, count: matched));
  }
  return buckets;
}

/// Male / female / unknown.
///
/// Anything that is not recognisably male or female is "unknown", including
/// blank — which is the honest answer for a member whose gender was never
/// recorded, and must never be able to swallow members who do have one.
List<DashboardMemberBucket> dashboardGenderBuckets(
  List<ChurchMembership> members,
) {
  return _bucketBy(members, {
    'male': (member) => _normalized(member.displayGender) == 'male',
    'female': (member) => _normalized(member.displayGender) == 'female',
    'unknown': (member) {
      final gender = _normalized(member.displayGender);
      return gender != 'male' && gender != 'female';
    },
  });
}

/// Children / youth / adults / seniors / unknown, by date of birth.
List<DashboardMemberBucket> dashboardAgeBuckets(
  List<ChurchMembership> members, {
  DateTime? asOf,
}) {
  int? ageOf(ChurchMembership member) =>
      dashboardMemberAge(member.displayDob, asOf: asOf);

  return _bucketBy(members, {
    'children': (member) {
      final age = ageOf(member);
      return age != null && age <= 12;
    },
    'youth': (member) {
      final age = ageOf(member);
      return age != null && age >= 13 && age <= 24;
    },
    'adults': (member) {
      final age = ageOf(member);
      return age != null && age >= 25 && age <= 59;
    },
    'seniors': (member) {
      final age = ageOf(member);
      return age != null && age >= 60;
    },
    'unknown': (member) => ageOf(member) == null,
  });
}

/// Family / individual / other / unspecified.
///
/// "Other" is a category that was set to something unrecognised;
/// "unspecified" is one that was never set. Collapsing them would hide a
/// data-entry problem behind an empty field.
List<DashboardMemberBucket> dashboardFamilyModeBuckets(
  List<ChurchMembership> members,
) {
  return _bucketBy(members, {
    'family': (member) => _normalized(member.category) == 'family',
    'individual': (member) => _normalized(member.category) == 'individual',
    'other': (member) {
      final category = _normalized(member.category);
      return category.isNotEmpty &&
          category != 'family' &&
          category != 'individual';
    },
    'unspecified': (member) => _normalized(member.category).isEmpty,
  });
}

/// Solemnized / not solemnized.
List<DashboardMemberBucket> dashboardSolemnizedBuckets(
  List<ChurchMembership> members,
) {
  return _bucketBy(members, {
    'solemnized': (member) => member.solemnizedBaptism,
    'not_solemnized': (member) => !member.solemnizedBaptism,
  });
}

/// The headline counts, from the same list the charts group.
DashboardMemberCounts dashboardMemberCounts(List<ChurchMembership> members) {
  if (members.isEmpty) return DashboardMemberCounts.empty;

  final approved = members.where((member) => member.approved).length;
  final families =
      members.where((member) => _normalized(member.category) == 'family')
          .length;
  final individuals =
      members.where((member) => _normalized(member.category) == 'individual')
          .length;
  final withGroups =
      members.where((member) => member.churchGroupIds.isNotEmpty).length;

  return DashboardMemberCounts(
    memberCount: members.length,
    approvedMembers: approved,
    pendingApprovals: members.length - approved,
    familyCount: families,
    individualCount: individuals,
    membersWithGroups: withGroups,
    groupParticipationRate: (withGroups / members.length * 100).round(),
  );
}
