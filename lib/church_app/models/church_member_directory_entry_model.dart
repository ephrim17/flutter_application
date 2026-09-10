import 'package:cloud_firestore/cloud_firestore.dart';

/// A deliberately reduced view of a church member, readable by any approved
/// member (not just staff) — see `mirrorMemberDirectory` in
/// functions/src/index.ts and `churches/{churchId}/memberDirectory/{uid}`
/// in firestore.rules. Never carries phone/email/address/baptism/financial/
/// notes — those stay on the staff-only `members/{uid}` doc.
class ChurchMemberDirectoryEntry {
  const ChurchMemberDirectoryEntry({
    required this.uid,
    required this.displayName,
    required this.displayPhotoUrl,
    required this.displayDob,
    required this.displayGender,
    required this.displayMaritalStatus,
  });

  final String uid;
  final String displayName;
  final String displayPhotoUrl;
  final DateTime? displayDob;
  final String displayGender;
  final String displayMaritalStatus;

  static String _string(dynamic value) =>
      value is String ? value.trim() : '';

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  factory ChurchMemberDirectoryEntry.fromFirestore(
    String uid,
    Map<String, dynamic> data,
  ) {
    return ChurchMemberDirectoryEntry(
      uid: uid,
      displayName: _string(data['displayName']),
      displayPhotoUrl: _string(data['displayPhotoUrl']),
      displayDob: _date(data['displayDob']),
      displayGender: _string(data['displayGender']),
      displayMaritalStatus: _string(data['displayMaritalStatus']),
    );
  }
}
