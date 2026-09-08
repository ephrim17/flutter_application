import 'package:cloud_firestore/cloud_firestore.dart';

/// The canonical, church-independent person record — `users/{uid}`.
///
/// Created once at signup (D5) and survives every church the person joins,
/// leaves, or is removed from. See
/// KT Files/architecture/user-church-decoupling-migration.md §5.1.
class UserIdentity {
  const UserIdentity({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.profilePhotoUrl = '',
    this.dob,
    this.gender = '',
    this.location = '',
    this.address = '',
    this.maritalStatus = '',
    this.weddingDay,
    this.educationalQualification = '',
    this.talentsAndGifts = const [],
    this.dayStreak = 0,
    this.lastStreakRecordedAt,
    this.lastActiveChurchId,
    this.profileComplete = false,
    this.schemaVersion = 1,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String profilePhotoUrl;
  final DateTime? dob;
  final String gender;
  final String location;
  final String address;
  final String maritalStatus;
  final DateTime? weddingDay;
  final String educationalQualification;
  final List<String> talentsAndGifts;

  /// Global — one streak per person, not per membership (D4).
  final int dayStreak;
  final DateTime? lastStreakRecordedAt;

  final String? lastActiveChurchId;

  /// Derived from the post-approval field set (§5.5) during signup/backfill;
  /// drives the non-blocking completion prompt.
  final bool profileComplete;

  final int schemaVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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

  factory UserIdentity.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserIdentity(
      uid: uid,
      name: _string(data['name']),
      email: _string(data['email']),
      phone: _string(data['phone']),
      profilePhotoUrl: _string(data['profilePhotoUrl']),
      dob: _date(data['dob']),
      gender: _string(data['gender']),
      location: _string(data['location']),
      address: _string(data['address']),
      maritalStatus: _string(data['maritalStatus']),
      weddingDay: _date(data['weddingDay']),
      educationalQualification: _string(data['educationalQualification']),
      talentsAndGifts: _strings(data['talentsAndGifts']),
      dayStreak: _int(data['dayStreak']),
      lastStreakRecordedAt: _date(data['lastStreakRecordedAt']),
      lastActiveChurchId: data['lastActiveChurchId'] == null
          ? null
          : _string(data['lastActiveChurchId']),
      profileComplete: _bool(data['profileComplete']),
      schemaVersion: data['schemaVersion'] == null ? 1 : _int(data['schemaVersion']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'profilePhotoUrl': profilePhotoUrl,
      'dob': dob != null ? Timestamp.fromDate(dob!) : null,
      'gender': gender,
      'location': location,
      'address': address,
      'maritalStatus': maritalStatus,
      'weddingDay': weddingDay != null ? Timestamp.fromDate(weddingDay!) : null,
      'educationalQualification': educationalQualification,
      'talentsAndGifts': talentsAndGifts,
      'dayStreak': dayStreak,
      'lastStreakRecordedAt': lastStreakRecordedAt != null
          ? Timestamp.fromDate(lastStreakRecordedAt!)
          : null,
      'lastActiveChurchId': lastActiveChurchId,
      'profileComplete': profileComplete,
      'schemaVersion': schemaVersion,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserIdentity copyWith({
    String? name,
    String? email,
    String? phone,
    String? profilePhotoUrl,
    DateTime? dob,
    String? gender,
    String? location,
    String? address,
    String? maritalStatus,
    DateTime? weddingDay,
    String? educationalQualification,
    List<String>? talentsAndGifts,
    int? dayStreak,
    DateTime? lastStreakRecordedAt,
    String? lastActiveChurchId,
    bool? profileComplete,
  }) {
    return UserIdentity(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      location: location ?? this.location,
      address: address ?? this.address,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      weddingDay: weddingDay ?? this.weddingDay,
      educationalQualification:
          educationalQualification ?? this.educationalQualification,
      talentsAndGifts: talentsAndGifts ?? this.talentsAndGifts,
      dayStreak: dayStreak ?? this.dayStreak,
      lastStreakRecordedAt: lastStreakRecordedAt ?? this.lastStreakRecordedAt,
      lastActiveChurchId: lastActiveChurchId ?? this.lastActiveChurchId,
      profileComplete: profileComplete ?? this.profileComplete,
      schemaVersion: schemaVersion,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
