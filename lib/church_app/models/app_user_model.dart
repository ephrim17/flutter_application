import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String profilePhotoUrl;
  final String email;
  final String phone;
  final String contact;
  final String location;
  final String address;
  final String gender;
  final String category;
  final String familyId;
  final String maritalStatus;
  final DateTime? weddingDay;
  final int financialStabilityRating;
  final bool financialSupportRequired;
  final String educationalQualification;
  final List<String> talentsAndGifts;
  final List<String> churchGroupIds;
  final String role;
  final String authToken;
  final DateTime? dob;
  final DateTime? createdAt;
  final int dayStreak;
  final DateTime? lastStreakRecordedAt;
  final bool approved;
  final bool solemnizedBaptism;
  final DateTime? baptismDate;
  final String baptismCertificateNumber;
  final String baptismChurchName;
  final String baptismPastorName;
  final String marriageSolemnizationChurchType;
  final String marriageSolemnizationChurchName;
  final String membershipCurrentStatus;
  final String membershipNotes;
  final String additionalNotes;

  static int _parseDayStreak(dynamic raw) {
    if (raw is num) return raw.round();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }

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

  AppUser({
    required this.uid,
    required this.name,
    this.profilePhotoUrl = '',
    required this.email,
    required this.role,
    required this.approved,
    required this.phone,
    required this.contact,
    required this.location,
    required this.address,
    required this.gender,
    required this.category,
    required this.familyId,
    required this.maritalStatus,
    required this.weddingDay,
    required this.financialStabilityRating,
    required this.financialSupportRequired,
    required this.educationalQualification,
    required this.talentsAndGifts,
    required this.churchGroupIds,
    required this.authToken,
    required this.dob,
    this.createdAt,
    this.dayStreak = 0,
    this.lastStreakRecordedAt,
    this.solemnizedBaptism = false,
    this.baptismDate,
    this.baptismCertificateNumber = '',
    this.baptismChurchName = '',
    this.baptismPastorName = '',
    this.marriageSolemnizationChurchType = '',
    this.marriageSolemnizationChurchName = '',
    this.membershipCurrentStatus = '',
    this.membershipNotes = '',
    this.additionalNotes = '',
  });

  factory AppUser.fromFirestore(
    String uid,
    Map<String, dynamic> data,
  ) {
    final dobRaw = data['dob'];
    final weddingDayRaw = data['weddingDay'];
    final baptismDateRaw = data['baptismDate'];
    final createdAtRaw = data['createdAt'];
    final lastStreakRecordedAtRaw = data['lastStreakRecordedAt'];

    return AppUser(
      uid: uid,
      name: _string(data['name']),
      profilePhotoUrl: _string(data['profilePhotoUrl']),
      email: _string(data['email']),
      phone: _string(data['phone']),
      contact: _string(data['contact']),
      location: _string(data['location']),
      address: _string(data['address']),
      gender: _string(data['gender']),
      category: _string(data['category']),
      familyId: _string(data['familyId']),
      maritalStatus: _string(data['maritalStatus']),
      weddingDay: _date(weddingDayRaw),
      financialStabilityRating: _int(data['financialStabilityRating']),
      financialSupportRequired: _bool(data['financialSupportRequired']),
      educationalQualification: _string(data['educationalQualification']),
      talentsAndGifts: _strings(data['talentsAndGifts']),
      churchGroupIds: _strings(data['churchGroupIds']),
      authToken: _string(data['authToken']),
      dob: _date(dobRaw),
      createdAt: _date(createdAtRaw),
      dayStreak: _parseDayStreak(data['dayStreak']),
      lastStreakRecordedAt: _date(lastStreakRecordedAtRaw),
      role: _string(data['role'], fallback: 'user'),
      approved: _bool(data['approved']),
      solemnizedBaptism: _bool(data['solemnizedBaptism']),
      baptismDate: _date(baptismDateRaw),
      baptismCertificateNumber: _string(data['baptismCertificateNumber']),
      baptismChurchName: _string(data['baptismChurchName']),
      baptismPastorName: _string(data['baptismPastorName']),
      marriageSolemnizationChurchType:
          _string(data['marriageSolemnizationChurchType']),
      marriageSolemnizationChurchName:
          _string(data['marriageSolemnizationChurchName']),
      membershipCurrentStatus: _string(data['membershipCurrentStatus']),
      membershipNotes: _string(data['membershipNotes']),
      additionalNotes: _string(data['additionalNotes']),
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final dobRaw = json['dob'];
    final weddingDayRaw = json['weddingDay'];
    final baptismDateRaw = json['baptismDate'];
    final createdAtRaw = json['createdAt'];
    final lastStreakRecordedAtRaw = json['lastStreakRecordedAt'];

    return AppUser(
      uid: _string(json['uid']),
      phone: _string(json['phone']),
      contact: _string(json['contact']),
      name: _string(json['name']),
      profilePhotoUrl: _string(json['profilePhotoUrl']),
      email: _string(json['email']),
      location: _string(json['location']),
      address: _string(json['address']),
      gender: _string(json['gender']),
      category: _string(json['category']),
      familyId: _string(json['familyId']),
      maritalStatus: _string(json['maritalStatus']),
      weddingDay: _date(weddingDayRaw),
      financialStabilityRating: _int(json['financialStabilityRating']),
      financialSupportRequired: _bool(json['financialSupportRequired']),
      educationalQualification: _string(json['educationalQualification']),
      talentsAndGifts: _strings(json['talentsAndGifts']),
      churchGroupIds: _strings(json['churchGroupIds']),
      authToken: _string(json['authToken']),
      dob: _date(dobRaw),
      createdAt: _date(createdAtRaw),
      dayStreak: _parseDayStreak(json['dayStreak']),
      lastStreakRecordedAt: _date(lastStreakRecordedAtRaw),
      role: _string(json['role'], fallback: 'user'),
      approved: _bool(json['approved']),
      solemnizedBaptism: _bool(json['solemnizedBaptism']),
      baptismDate: _date(baptismDateRaw),
      baptismCertificateNumber: _string(json['baptismCertificateNumber']),
      baptismChurchName: _string(json['baptismChurchName']),
      baptismPastorName: _string(json['baptismPastorName']),
      marriageSolemnizationChurchType:
          _string(json['marriageSolemnizationChurchType']),
      marriageSolemnizationChurchName:
          _string(json['marriageSolemnizationChurchName']),
      membershipCurrentStatus: _string(json['membershipCurrentStatus']),
      membershipNotes: _string(json['membershipNotes']),
      additionalNotes: _string(json['additionalNotes']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'profilePhotoUrl': profilePhotoUrl,
      'email': email,
      'phone': phone,
      'contact': contact,
      'location': location,
      'address': address,
      'gender': gender,
      'category': category,
      'familyId': familyId,
      'maritalStatus': maritalStatus,
      'weddingDay': weddingDay != null ? Timestamp.fromDate(weddingDay!) : null,
      'financialStabilityRating': financialStabilityRating,
      'financialSupportRequired': financialSupportRequired,
      'educationalQualification': educationalQualification,
      'talentsAndGifts': talentsAndGifts,
      'churchGroupIds': churchGroupIds,
      'role': role,
      'authToken': authToken,
      'approved': approved,
      'dob': dob != null ? Timestamp.fromDate(dob!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'dayStreak': dayStreak.toString(),
      'lastStreakRecordedAt': lastStreakRecordedAt != null
          ? Timestamp.fromDate(lastStreakRecordedAt!)
          : null,
      'solemnizedBaptism': solemnizedBaptism,
      'baptismDate':
          baptismDate != null ? Timestamp.fromDate(baptismDate!) : null,
      'baptismCertificateNumber': baptismCertificateNumber,
      'baptismChurchName': baptismChurchName,
      'baptismPastorName': baptismPastorName,
      'marriageSolemnizationChurchType': marriageSolemnizationChurchType,
      'marriageSolemnizationChurchName': marriageSolemnizationChurchName,
      'membershipCurrentStatus': membershipCurrentStatus,
      'membershipNotes': membershipNotes,
      'additionalNotes': additionalNotes,
    };
  }
}
