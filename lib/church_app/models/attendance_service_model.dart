import 'package:cloud_firestore/cloud_firestore.dart';

/// One gathering, and who was at it — `churches/{churchId}/services/{id}`.
///
/// The service is the record, not the person. Attendance is a list of member
/// ids on the service document rather than a row per person per service: a
/// church marks a whole congregation in one sitting, so one document written
/// once is both cheaper and far easier to correct than N writes that can
/// half-succeed. The lists are small (a congregation, not a mailing list),
/// and Firestore's 1 MiB document ceiling holds tens of thousands of ids.
class AttendanceService {
  const AttendanceService({
    required this.id,
    required this.date,
    required this.type,
    this.subheader = '',
    this.present = const <String>[],
    this.visitorCount = 0,
    this.childrenCount = 0,
    this.notes = '',
    this.createdBy = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;

  /// Date-only, local. Two services on one date are distinct documents —
  /// a church can hold a morning and an evening meeting.
  final DateTime date;

  /// A key into `attendance.service_type.*`, not display text, so the stored
  /// value survives a church renaming its service types or switching
  /// language. See [attendanceServiceTypeKeys].
  final String type;

  /// The church's own name for this particular gathering, free text — "2nd
  /// service", "Tamil service", "Youth-led". A service type alone cannot tell
  /// two gatherings of the same kind on the same date apart, and three Sunday
  /// worships in one day is the ordinary case, not the edge case.
  ///
  /// Free text rather than another key list: only the church knows what it
  /// calls its own services, and a fixed list would be wrong everywhere.
  /// Empty is normal and renders nothing.
  final String subheader;

  /// Member document ids present. Order is not meaningful.
  final List<String> present;

  /// People who are not members, counted but not named.
  final int visitorCount;
  final int childrenCount;

  final String notes;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Total heads at the gathering: named members plus both headcounts.
  int get totalAttendance => present.length + visitorCount + childrenCount;

  factory AttendanceService.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return AttendanceService(
      id: id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime(1970),
      type: (data['type'] ?? '').toString().trim(),
      subheader: (data['subheader'] ?? '').toString().trim(),
      present: (data['present'] as Iterable? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      visitorCount: (data['visitorCount'] as num?)?.toInt() ?? 0,
      childrenCount: (data['childrenCount'] as num?)?.toInt() ?? 0,
      notes: (data['notes'] ?? '').toString().trim(),
      createdBy: (data['createdBy'] ?? '').toString().trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'type': type,
      'subheader': subheader,
      'present': present,
      'visitorCount': visitorCount,
      'childrenCount': childrenCount,
      'notes': notes,
      'createdBy': createdBy,
    };
  }

  AttendanceService copyWith({
    DateTime? date,
    String? type,
    String? subheader,
    List<String>? present,
    int? visitorCount,
    int? childrenCount,
    String? notes,
  }) {
    return AttendanceService(
      id: id,
      date: date ?? this.date,
      type: type ?? this.type,
      subheader: subheader ?? this.subheader,
      present: present ?? this.present,
      visitorCount: visitorCount ?? this.visitorCount,
      childrenCount: childrenCount ?? this.childrenCount,
      notes: notes ?? this.notes,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// The service types offered when recording, in display order.
///
/// Stored on the document as these keys; each has a matching
/// `attendance.service_type.<key>` entry in `defaultChurchTextContents`, so a
/// church can rename "Midweek service" to whatever it actually calls that
/// gathering without rewriting history.
const List<String> attendanceServiceTypeKeys = <String>[
  'sunday_worship',
  'midweek',
  'prayer_meeting',
  'fasting_prayer',
  'bible_study',
  'youth_meeting',
  'special_meeting',
];
