import 'package:cloud_firestore/cloud_firestore.dart';

/// A person's membership in one church — `churches/{cid}/members/{docId}`.
///
/// Membership-only: identity fields (name, phone, dob...) live on
/// `users/{uid}` (see [UserIdentity]) and never on this doc. See
/// KT Files/architecture/user-church-decoupling-migration.md §5.1.
///
/// [docId] is the auth uid for a self-signed-up or linked member, or a
/// random Firestore id for an admin-created member with no account (§9.3,
/// §9.4) — never mint `users/{randomId}` for these. [uid] mirrors [docId]
/// for a linked member and is empty otherwise; it exists as its own field
/// (not just the doc id) because rules can only `get()` a constructible
/// path, not query by doc id (§9.7) — the `members` collection-group read
/// rule matches on this field (§5.2, §9.9).
class ChurchMembership {
  const ChurchMembership({
    required this.docId,
    required this.churchId,
    this.uid = '',
    this.linkedUid,
    this.approved = false,
    this.role = 'user',
    this.category = '',
    this.familyId = '',
    this.churchGroupIds = const [],
    this.membershipCurrentStatus = '',
    this.membershipNotes = '',
    this.additionalNotes = '',
    this.solemnizedBaptism = false,
    this.baptismDate,
    this.baptismCertificateNumber = '',
    this.baptismChurchName = '',
    this.baptismPastorName = '',
    this.marriageSolemnizationChurchType = '',
    this.marriageSolemnizationChurchName = '',
    this.financialStabilityRating = 0,
    this.financialSupportRequired = false,
    this.joinedAt,
    this.schemaVersion = 1,
    this.displayName = '',
    this.displayEmail = '',
    this.displayPhone = '',
    this.displayPhotoUrl = '',
    this.displayDob,
    this.displayGender = '',
    this.identitySyncedAt,
  });

  final String docId;
  final String churchId;

  /// Equal to [docId] when this row is linked to a real account; empty for
  /// an unlinked (admin-created, no-auth) member. See class doc and §9.3/§9.7.
  final String uid;

  /// Same linkage signal as [uid], named for its use in the Phase 6 fan-out
  /// and the display*-field ownership rule (§9.2): non-null means the
  /// display* fields below are a read-only cache of `users/{uid}`; null
  /// means they are this row's own authoritative profile.
  final String? linkedUid;

  final bool approved;

  /// Display/analytics only — NEVER an authority source (§9.1). Real
  /// authority is: approved (member), church admin email allowlist, or the
  /// global superAdmins record.
  final String role;

  final String category;
  final String familyId;
  final List<String> churchGroupIds;
  final String membershipCurrentStatus;
  final String membershipNotes;
  final String additionalNotes;

  final bool solemnizedBaptism;
  final DateTime? baptismDate;
  final String baptismCertificateNumber;
  final String baptismChurchName;
  final String baptismPastorName;
  final String marriageSolemnizationChurchType;
  final String marriageSolemnizationChurchName;

  /// Church-private — never exposed to the member themselves (§4.1).
  final int financialStabilityRating;
  final bool financialSupportRequired;

  final DateTime? joinedAt;
  final int schemaVersion;

  /// Cache (linked) or authoritative (unlinked) — see [linkedUid] doc above.
  final String displayName;
  final String displayEmail;
  final String displayPhone;
  final String displayPhotoUrl;
  final DateTime? displayDob;
  final String displayGender;
  final DateTime? identitySyncedAt;

  bool get isLinked => linkedUid != null && linkedUid!.isNotEmpty;

  static String _string(dynamic value, {String fallback = ''}) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  static bool _bool(dynamic value) => value == true;

  static int _int(dynamic value) {
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<String> _strings(dynamic value) {
    if (value is! Iterable) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  factory ChurchMembership.fromFirestore(
    String docId,
    String churchId,
    Map<String, dynamic> data,
  ) {
    final linkedUidRaw = data['linkedUid'];
    return ChurchMembership(
      docId: docId,
      churchId: churchId,
      uid: _string(data['uid']),
      linkedUid: linkedUidRaw == null ? null : _string(linkedUidRaw),
      approved: _bool(data['approved']),
      role: _string(data['role'], fallback: 'user'),
      category: _string(data['category']),
      familyId: _string(data['familyId']),
      churchGroupIds: _strings(data['churchGroupIds']),
      membershipCurrentStatus: _string(data['membershipCurrentStatus']),
      membershipNotes: _string(data['membershipNotes']),
      additionalNotes: _string(data['additionalNotes']),
      solemnizedBaptism: _bool(data['solemnizedBaptism']),
      baptismDate: _date(data['baptismDate']),
      baptismCertificateNumber: _string(data['baptismCertificateNumber']),
      baptismChurchName: _string(data['baptismChurchName']),
      baptismPastorName: _string(data['baptismPastorName']),
      marriageSolemnizationChurchType:
          _string(data['marriageSolemnizationChurchType']),
      marriageSolemnizationChurchName:
          _string(data['marriageSolemnizationChurchName']),
      financialStabilityRating: _int(data['financialStabilityRating']),
      financialSupportRequired: _bool(data['financialSupportRequired']),
      joinedAt: _date(data['joinedAt']),
      schemaVersion: data['schemaVersion'] == null ? 1 : _int(data['schemaVersion']),
      displayName: _string(data['displayName']),
      displayEmail: _string(data['displayEmail']),
      displayPhone: _string(data['displayPhone']),
      displayPhotoUrl: _string(data['displayPhotoUrl']),
      displayDob: _date(data['displayDob']),
      displayGender: _string(data['displayGender']),
      identitySyncedAt: _date(data['identitySyncedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'linkedUid': linkedUid,
      'approved': approved,
      'role': role,
      'category': category,
      'familyId': familyId,
      'churchGroupIds': churchGroupIds,
      'membershipCurrentStatus': membershipCurrentStatus,
      'membershipNotes': membershipNotes,
      'additionalNotes': additionalNotes,
      'solemnizedBaptism': solemnizedBaptism,
      'baptismDate':
          baptismDate != null ? Timestamp.fromDate(baptismDate!) : null,
      'baptismCertificateNumber': baptismCertificateNumber,
      'baptismChurchName': baptismChurchName,
      'baptismPastorName': baptismPastorName,
      'marriageSolemnizationChurchType': marriageSolemnizationChurchType,
      'marriageSolemnizationChurchName': marriageSolemnizationChurchName,
      'financialStabilityRating': financialStabilityRating,
      'financialSupportRequired': financialSupportRequired,
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : FieldValue.serverTimestamp(),
      'schemaVersion': schemaVersion,
      'displayName': displayName,
      'displayEmail': displayEmail,
      'displayPhone': displayPhone,
      'displayPhotoUrl': displayPhotoUrl,
      'displayDob': displayDob != null ? Timestamp.fromDate(displayDob!) : null,
      'displayGender': displayGender,
      'identitySyncedAt': identitySyncedAt != null
          ? Timestamp.fromDate(identitySyncedAt!)
          : null,
    };
  }
}
