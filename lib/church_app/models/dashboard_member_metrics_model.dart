import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardPreviewMember {
  const DashboardPreviewMember({
    required this.uid,
    required this.name,
    required this.secondary,
    this.approved = false,
  });

  final String uid;
  final String name;
  final String secondary;
  final bool approved;

  factory DashboardPreviewMember.fromMap(Map<String, dynamic> map) {
    return DashboardPreviewMember(
      uid: (map['uid'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      secondary: (map['secondary'] ?? '').toString(),
      approved: map['approved'] == true,
    );
  }
}

class DashboardMetricBucket {
  const DashboardMetricBucket({
    required this.id,
    required this.label,
    required this.count,
    required this.previewMembers,
  });

  final String id;
  final String label;
  final int count;
  final List<DashboardPreviewMember> previewMembers;

  factory DashboardMetricBucket.fromMap(Map<String, dynamic> map) {
    final previews = (map['previewMembers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => DashboardPreviewMember.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);

    return DashboardMetricBucket(
      id: (map['id'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      count: (map['count'] as num?)?.round() ?? 0,
      previewMembers: previews,
    );
  }
}

class DashboardFamilyBucket {
  const DashboardFamilyBucket({
    required this.id,
    required this.label,
    required this.count,
    required this.familyIds,
  });

  final String id;
  final String label;
  final int count;
  final List<String> familyIds;

  factory DashboardFamilyBucket.fromMap(Map<String, dynamic> map) {
    return DashboardFamilyBucket(
      id: (map['id'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      count: (map['count'] as num?)?.round() ?? 0,
      familyIds: (map['familyIds'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
    );
  }
}

class DashboardMemberMetrics {
  const DashboardMemberMetrics({
    required this.memberCount,
    required this.approvedMembers,
    required this.pendingApprovals,
    required this.familyCount,
    required this.individualCount,
    required this.membersWithGroups,
    required this.groupParticipationRate,
    required this.recentJoinCount7d,
    required this.recentJoinCount30d,
    required this.recentJoinCount90d,
    required this.joinedThisYear,
    required this.activeStreakMembersCount,
    required this.membersWith7PlusCount,
    required this.activeStreakRate,
    required this.topStreakValue,
    required this.recentMembers,
    required this.genderBuckets,
    required this.ageBuckets,
    required this.familyModeBuckets,
    required this.solemnizedBuckets,
    required this.familyBuckets,
    this.firstRecordedAt,
    this.topStreakMember,
  });

  final int memberCount;
  final int approvedMembers;
  final int pendingApprovals;
  final int familyCount;
  final int individualCount;
  final int membersWithGroups;
  final int groupParticipationRate;
  final int recentJoinCount7d;
  final int recentJoinCount30d;
  final int recentJoinCount90d;
  final int joinedThisYear;
  final int activeStreakMembersCount;
  final int membersWith7PlusCount;
  final int activeStreakRate;
  final int topStreakValue;
  final DateTime? firstRecordedAt;
  final DashboardPreviewMember? topStreakMember;
  final List<DashboardPreviewMember> recentMembers;
  final List<DashboardMetricBucket> genderBuckets;
  final List<DashboardMetricBucket> ageBuckets;
  final List<DashboardMetricBucket> familyModeBuckets;
  final List<DashboardMetricBucket> solemnizedBuckets;
  final List<DashboardFamilyBucket> familyBuckets;

  static const empty = DashboardMemberMetrics(
    memberCount: 0,
    approvedMembers: 0,
    pendingApprovals: 0,
    familyCount: 0,
    individualCount: 0,
    membersWithGroups: 0,
    groupParticipationRate: 0,
    recentJoinCount7d: 0,
    recentJoinCount30d: 0,
    recentJoinCount90d: 0,
    joinedThisYear: 0,
    activeStreakMembersCount: 0,
    membersWith7PlusCount: 0,
    activeStreakRate: 0,
    topStreakValue: 0,
    recentMembers: <DashboardPreviewMember>[],
    genderBuckets: <DashboardMetricBucket>[],
    ageBuckets: <DashboardMetricBucket>[],
    familyModeBuckets: <DashboardMetricBucket>[],
    solemnizedBuckets: <DashboardMetricBucket>[],
    familyBuckets: <DashboardFamilyBucket>[],
  );

  factory DashboardMemberMetrics.fromMap(Map<String, dynamic> map) {
    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    List<DashboardMetricBucket> readMetricBuckets(String key) {
      return (map[key] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => DashboardMetricBucket.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    }

    List<DashboardFamilyBucket> readFamilyBuckets(String key) {
      return (map[key] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => DashboardFamilyBucket.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    }

    final recentMembers = (map['recentMembers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => DashboardPreviewMember.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);

    final topStreakMemberRaw = map['topStreakMember'];

    return DashboardMemberMetrics(
      memberCount: (map['memberCount'] as num?)?.round() ?? 0,
      approvedMembers: (map['approvedMembers'] as num?)?.round() ?? 0,
      pendingApprovals: (map['pendingApprovals'] as num?)?.round() ?? 0,
      familyCount: (map['familyCount'] as num?)?.round() ?? 0,
      individualCount: (map['individualCount'] as num?)?.round() ?? 0,
      membersWithGroups: (map['membersWithGroups'] as num?)?.round() ?? 0,
      groupParticipationRate:
          (map['groupParticipationRate'] as num?)?.round() ?? 0,
      recentJoinCount7d: (map['recentJoinCount7d'] as num?)?.round() ?? 0,
      recentJoinCount30d: (map['recentJoinCount30d'] as num?)?.round() ?? 0,
      recentJoinCount90d: (map['recentJoinCount90d'] as num?)?.round() ?? 0,
      joinedThisYear: (map['joinedThisYear'] as num?)?.round() ?? 0,
      activeStreakMembersCount:
          (map['activeStreakMembersCount'] as num?)?.round() ?? 0,
      membersWith7PlusCount:
          (map['membersWith7PlusCount'] as num?)?.round() ?? 0,
      activeStreakRate: (map['activeStreakRate'] as num?)?.round() ?? 0,
      topStreakValue: (map['topStreakValue'] as num?)?.round() ?? 0,
      firstRecordedAt: readDate(map['firstRecordedAt']),
      topStreakMember:
          topStreakMemberRaw is Map<String, dynamic>
              ? DashboardPreviewMember.fromMap(topStreakMemberRaw)
              : topStreakMemberRaw is Map
                  ? DashboardPreviewMember.fromMap(
                      Map<String, dynamic>.from(topStreakMemberRaw),
                    )
                  : null,
      recentMembers: recentMembers,
      genderBuckets: readMetricBuckets('genderBuckets'),
      ageBuckets: readMetricBuckets('ageBuckets'),
      familyModeBuckets: readMetricBuckets('familyModeBuckets'),
      solemnizedBuckets: readMetricBuckets('solemnizedBuckets'),
      familyBuckets: readFamilyBuckets('familyBuckets'),
    );
  }
}
