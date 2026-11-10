import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/dashboard_member_stats.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/models/dashboard_member_metrics_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/announcement_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/event_model.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';

@immutable
class DashboardViewState {
  const DashboardViewState({
    required this.isAdmin,
    required this.churchTitle,
    required this.churchId,
    required this.memberMetrics,
    required this.members,
    required this.prayers,
    required this.announcements,
    required this.events,
    required this.admins,
    required this.selectedChartMode,
    required this.selectedChartIndex,
  });

  factory DashboardViewState.accessDenied({
    required String churchTitle,
    required DashboardMemberChartMode selectedChartMode,
  }) {
    return DashboardViewState(
      isAdmin: false,
      churchTitle: churchTitle,
      churchId: null,
      memberMetrics: DashboardMemberMetrics.empty,
      members: const <ChurchMembership>[],
      prayers: const <PrayerRequest>[],
      announcements: const <Announcement>[],
      events: const <Event>[],
      admins: const <String>[],
      selectedChartMode: selectedChartMode,
      selectedChartIndex: 0,
    );
  }

  final bool isAdmin;
  final String churchTitle;
  final String? churchId;
  /// Server-computed metrics. Only the streak numbers and the join history
  /// are read from here now — member *composition* is derived from [members],
  /// because a stored aggregate of a list the screen already holds is a
  /// second answer that can disagree with the first. See
  /// `dashboard_member_stats.dart`.
  final DashboardMemberMetrics memberMetrics;

  /// The church's members, as loaded for this screen. Every chart bucket and
  /// headline count below is a grouping of this list.
  final List<ChurchMembership> members;

  final List<PrayerRequest> prayers;
  final List<Announcement> announcements;
  final List<Event> events;
  final List<String> admins;
  final DashboardMemberChartMode selectedChartMode;
  final int selectedChartIndex;

  DashboardOverviewMetrics get metrics => DashboardOverviewMetrics.fromState(
        counts: dashboardMemberCounts(members),
        prayers: prayers,
        announcements: announcements,
        events: events,
        admins: admins,
      );

  List<PrayerRequest> get expiringPrayers {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 7));
    return prayers
        .where(
          (prayer) =>
              !prayer.expiryDate.isBefore(now) &&
              !prayer.expiryDate.isAfter(cutoff),
        )
        .toList(growable: false);
  }

  int get contentGapCount {
    var gaps = 0;
    if (announcements.isEmpty) gaps += 1;
    if (events.isEmpty) gaps += 1;
    return gaps;
  }

  List<DashboardMemberGroup> get memberGroups {
    final buckets = switch (selectedChartMode) {
      DashboardMemberChartMode.gender => dashboardGenderBuckets(members),
      DashboardMemberChartMode.age => dashboardAgeBuckets(members),
      DashboardMemberChartMode.family => dashboardFamilyModeBuckets(members),
      DashboardMemberChartMode.solemnized =>
        dashboardSolemnizedBuckets(members),
    };

    return buckets
        .map(
          (bucket) => DashboardMemberGroup(
            id: bucket.id,
            labelKey: dashboardBucketLabelKey(selectedChartMode, bucket.id),
            color: dashboardBucketColor(selectedChartMode, bucket.id),
            count: bucket.count,
          ),
        )
        .where((group) => group.count > 0)
        .toList(growable: false);
  }

  int get selectedChartSafeIndex {
    final groups = memberGroups;
    if (groups.isEmpty) return -1;
    return selectedChartIndex.clamp(0, groups.length - 1);
  }

  DashboardViewState copyWith({
    bool? isAdmin,
    String? churchTitle,
    String? churchId,
    DashboardMemberMetrics? memberMetrics,
    List<ChurchMembership>? members,
    List<PrayerRequest>? prayers,
    List<Announcement>? announcements,
    List<Event>? events,
    List<String>? admins,
    DashboardMemberChartMode? selectedChartMode,
    int? selectedChartIndex,
  }) {
    return DashboardViewState(
      isAdmin: isAdmin ?? this.isAdmin,
      churchTitle: churchTitle ?? this.churchTitle,
      churchId: churchId ?? this.churchId,
      memberMetrics: memberMetrics ?? this.memberMetrics,
      members: members ?? this.members,
      prayers: prayers ?? this.prayers,
      announcements: announcements ?? this.announcements,
      events: events ?? this.events,
      admins: admins ?? this.admins,
      selectedChartMode: selectedChartMode ?? this.selectedChartMode,
      selectedChartIndex: selectedChartIndex ?? this.selectedChartIndex,
    );
  }

  DashboardViewState normalized() {
    final groups = memberGroups;
    if (groups.isEmpty) {
      return copyWith(selectedChartIndex: 0);
    }
    final safeIndex = selectedChartIndex.clamp(0, groups.length - 1);
    if (safeIndex == selectedChartIndex) return this;
    return copyWith(selectedChartIndex: safeIndex);
  }
}

enum DashboardMemberChartMode {
  gender('dashboard.gender_view', 'dashboard.gender_view_description'),
  age(
    'dashboard.age_view',
    'dashboard.age_view_description',
  ),
  family(
    'dashboard.family_view',
    'dashboard.family_view_description',
  ),
  solemnized(
    'dashboard.solemnized_view',
    'dashboard.solemnized_view_description',
  );

  const DashboardMemberChartMode(this.labelKey, this.descriptionKey);

  final String labelKey;
  final String descriptionKey;
}

@immutable
class DashboardMemberGroup {
  const DashboardMemberGroup({
    required this.id,
    required this.labelKey,
    required this.color,
    required this.count,
  });

  /// Stable bucket key (`male`, `seniors`, `not_solemnized`). Used for
  /// colours, for the drill-down's filter, and for analytics — never shown.
  final String id;

  /// Text-content key for the visible label, resolved with `context.t()`.
  /// The label itself is never stored or compared.
  final String labelKey;

  final Color color;
  final int count;
}

@immutable
class DashboardOverviewMetrics {
  const DashboardOverviewMetrics({
    required this.memberCount,
    required this.approvedMembers,
    required this.pendingApprovals,
    required this.familyCount,
    required this.individualCount,
    required this.prayerCount,
    required this.adminCount,
    required this.announcementCount,
    required this.eventCount,
    required this.membersWithGroups,
    required this.groupParticipationRate,
  });

  final int memberCount;
  final int approvedMembers;
  final int pendingApprovals;
  final int familyCount;
  final int individualCount;
  final int prayerCount;
  final int adminCount;
  final int announcementCount;
  final int eventCount;
  final int membersWithGroups;
  final int groupParticipationRate;

  factory DashboardOverviewMetrics.fromState({
    required DashboardMemberCounts counts,
    required List<PrayerRequest> prayers,
    required List<Announcement> announcements,
    required List<Event> events,
    required List<String> admins,
  }) {
    return DashboardOverviewMetrics(
      memberCount: counts.memberCount,
      approvedMembers: counts.approvedMembers,
      pendingApprovals: counts.pendingApprovals,
      familyCount: counts.familyCount,
      individualCount: counts.individualCount,
      prayerCount: prayers.length,
      adminCount: admins.length,
      announcementCount: announcements.length,
      eventCount: events.length,
      membersWithGroups: counts.membersWithGroups,
      groupParticipationRate: counts.groupParticipationRate,
    );
  }
}

String formatDashboardCategory(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}

/// Text-content key for a bucket's visible label.
///
/// Keyed off the bucket id, not the label — the label is the thing being
/// looked up, and a church may have renamed it.
String dashboardBucketLabelKey(DashboardMemberChartMode mode, String id) {
  return 'dashboard.${mode.name}_bucket.$id';
}

/// A bucket's chart colour, keyed off its stable id.
///
/// This used to switch on the English label, which meant any church running
/// in another language got grey for every segment.
Color dashboardBucketColor(DashboardMemberChartMode mode, String id) {
  const fallback = Colors.grey;
  switch (mode) {
    case DashboardMemberChartMode.gender:
      return switch (id) {
        'male' => Colors.blue,
        'female' => Colors.pink,
        _ => fallback,
      };
    case DashboardMemberChartMode.age:
      return switch (id) {
        'children' => Colors.orange,
        'youth' => Colors.purple,
        'adults' => Colors.green,
        'seniors' => Colors.teal,
        _ => fallback,
      };
    case DashboardMemberChartMode.family:
      return switch (id) {
        'family' => Colors.indigo,
        'individual' => Colors.cyan,
        'other' => Colors.amber,
        _ => fallback,
      };
    case DashboardMemberChartMode.solemnized:
      return switch (id) {
        'solemnized' => Colors.deepPurple,
        'not_solemnized' => Colors.blueGrey,
        _ => fallback,
      };
  }
}
