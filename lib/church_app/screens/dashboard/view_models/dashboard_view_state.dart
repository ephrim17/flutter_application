import 'package:flutter/material.dart';
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
  final DashboardMemberMetrics memberMetrics;
  final List<PrayerRequest> prayers;
  final List<Announcement> announcements;
  final List<Event> events;
  final List<String> admins;
  final DashboardMemberChartMode selectedChartMode;
  final int selectedChartIndex;

  DashboardOverviewMetrics get metrics => DashboardOverviewMetrics.fromState(
        memberMetrics: memberMetrics,
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
      DashboardMemberChartMode.gender => memberMetrics.genderBuckets,
      DashboardMemberChartMode.age => memberMetrics.ageBuckets,
      DashboardMemberChartMode.family => memberMetrics.familyModeBuckets,
      DashboardMemberChartMode.solemnized => memberMetrics.solemnizedBuckets,
    };

    return buckets
        .map(
          (bucket) => DashboardMemberGroup(
            label: bucket.label,
            color: dashboardBucketColor(selectedChartMode, bucket.label),
            count: bucket.count,
            previewMembers: bucket.previewMembers,
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

  DashboardMemberGroup? get selectedMemberGroup {
    final groups = memberGroups;
    final safeIndex = selectedChartSafeIndex;
    if (safeIndex < 0 || safeIndex >= groups.length) return null;
    return groups[safeIndex];
  }

  DashboardViewState copyWith({
    bool? isAdmin,
    String? churchTitle,
    String? churchId,
    DashboardMemberMetrics? memberMetrics,
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
  gender('Gender View', 'See how member records are distributed by gender.'),
  age(
    'Age View',
    'Track the age mix across children, youth, adults, and seniors.',
  ),
  family(
    'Family Mode',
    'Understand how many profiles are registered as families or individuals.',
  ),
  solemnized(
    'Marriage View',
    'See how many members are solemnized across the recorded membership base.',
  );

  const DashboardMemberChartMode(this.label, this.description);

  final String label;
  final String description;
}

@immutable
class DashboardMemberGroup {
  const DashboardMemberGroup({
    required this.label,
    required this.color,
    required this.count,
    required this.previewMembers,
  });

  final String label;
  final Color color;
  final int count;
  final List<DashboardPreviewMember> previewMembers;
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
    required DashboardMemberMetrics memberMetrics,
    required List<PrayerRequest> prayers,
    required List<Announcement> announcements,
    required List<Event> events,
    required List<String> admins,
  }) {
    return DashboardOverviewMetrics(
      memberCount: memberMetrics.memberCount,
      approvedMembers: memberMetrics.approvedMembers,
      pendingApprovals: memberMetrics.pendingApprovals,
      familyCount: memberMetrics.familyCount,
      individualCount: memberMetrics.individualCount,
      prayerCount: prayers.length,
      adminCount: admins.length,
      announcementCount: announcements.length,
      eventCount: events.length,
      membersWithGroups: memberMetrics.membersWithGroups,
      groupParticipationRate: memberMetrics.groupParticipationRate,
    );
  }
}

String formatDashboardCategory(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'Not provided';
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}

Color dashboardBucketColor(DashboardMemberChartMode mode, String label) {
  switch (mode) {
    case DashboardMemberChartMode.gender:
      switch (label) {
        case 'Male':
          return Colors.blue;
        case 'Female':
          return Colors.pink;
        default:
          return Colors.grey;
      }
    case DashboardMemberChartMode.age:
      switch (label) {
        case 'Children':
          return Colors.orange;
        case 'Youth':
          return Colors.purple;
        case 'Adults':
          return Colors.green;
        case 'Seniors':
          return Colors.teal;
        default:
          return Colors.grey;
      }
    case DashboardMemberChartMode.family:
      switch (label) {
        case 'Family':
          return Colors.indigo;
        case 'Individual':
          return Colors.cyan;
        case 'Other':
          return Colors.amber;
        default:
          return Colors.grey;
      }
    case DashboardMemberChartMode.solemnized:
      switch (label) {
        case 'Solemnized':
          return Colors.deepPurple;
        case 'Not solemnized':
          return Colors.blueGrey;
        default:
          return Colors.grey;
      }
  }
}
