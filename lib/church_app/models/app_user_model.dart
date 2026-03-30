import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
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

  AppUser({
    required this.uid,
    required this.name,
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
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      contact: data['contact'] ?? '',
      location: data['location'] ?? '',
      address: data['address'] ?? '',
      gender: data['gender'] ?? '',
      category: data['category'] ?? '',
      familyId: data['familyId'] ?? '',
      maritalStatus: data['maritalStatus'] ?? '',
      weddingDay: weddingDayRaw is Timestamp
          ? weddingDayRaw.toDate()
          : weddingDayRaw is DateTime
              ? weddingDayRaw
              : null,
      financialStabilityRating:
          (data['financialStabilityRating'] as num?)?.round() ?? 0,
      financialSupportRequired: data['financialSupportRequired'] ?? false,
      educationalQualification: data['educationalQualification'] ?? '',
      talentsAndGifts: (data['talentsAndGifts'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      churchGroupIds: (data['churchGroupIds'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      authToken: data['authToken'] ?? '',
      dob: dobRaw is Timestamp
          ? dobRaw.toDate()
          : dobRaw is DateTime
              ? dobRaw
              : null,
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : createdAtRaw is DateTime
              ? createdAtRaw
              : null,
      dayStreak: _parseDayStreak(data['dayStreak']),
      lastStreakRecordedAt: lastStreakRecordedAtRaw is Timestamp
          ? lastStreakRecordedAtRaw.toDate()
          : lastStreakRecordedAtRaw is DateTime
              ? lastStreakRecordedAtRaw
              : null,
      role: data['role'] ?? 'user',
      approved: data['approved'] ?? false,
      solemnizedBaptism: data['solemnizedBaptism'] ?? false,
      baptismDate: baptismDateRaw is Timestamp
          ? baptismDateRaw.toDate()
          : baptismDateRaw is DateTime
              ? baptismDateRaw
              : null,
      baptismCertificateNumber: data['baptismCertificateNumber'] ?? '',
      baptismChurchName: data['baptismChurchName'] ?? '',
      baptismPastorName: data['baptismPastorName'] ?? '',
      marriageSolemnizationChurchType:
          data['marriageSolemnizationChurchType'] ?? '',
      marriageSolemnizationChurchName:
          data['marriageSolemnizationChurchName'] ?? '',
      membershipCurrentStatus: data['membershipCurrentStatus'] ?? '',
      membershipNotes: data['membershipNotes'] ?? '',
      additionalNotes: data['additionalNotes'] ?? '',
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final dobRaw = json['dob'];
    final weddingDayRaw = json['weddingDay'];
    final baptismDateRaw = json['baptismDate'];
    final createdAtRaw = json['createdAt'];
    final lastStreakRecordedAtRaw = json['lastStreakRecordedAt'];

    return AppUser(
      uid: json['uid'] ?? '',
      phone: json['phone'] ?? '',
      contact: json['contact'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      location: json['location'] ?? '',
      address: json['address'] ?? '',
      gender: json['gender'] ?? '',
      category: json['category'] ?? '',
      familyId: json['familyId'] ?? '',
      maritalStatus: json['maritalStatus'] ?? '',
      weddingDay: weddingDayRaw is Timestamp
          ? weddingDayRaw.toDate()
          : weddingDayRaw is DateTime
              ? weddingDayRaw
              : null,
      financialStabilityRating:
          (json['financialStabilityRating'] as num?)?.round() ?? 0,
      financialSupportRequired: json['financialSupportRequired'] ?? false,
      educationalQualification: json['educationalQualification'] ?? '',
      talentsAndGifts: (json['talentsAndGifts'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      churchGroupIds: (json['churchGroupIds'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      authToken: json['authToken'] ?? '',
      dob: dobRaw is Timestamp
          ? dobRaw.toDate()
          : dobRaw is DateTime
              ? dobRaw
              : null,
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : createdAtRaw is DateTime
              ? createdAtRaw
              : null,
      dayStreak: _parseDayStreak(json['dayStreak']),
      lastStreakRecordedAt: lastStreakRecordedAtRaw is Timestamp
          ? lastStreakRecordedAtRaw.toDate()
          : lastStreakRecordedAtRaw is DateTime
              ? lastStreakRecordedAtRaw
              : null,
      role: json['role'] ?? 'user',
      approved: json['approved'] ?? false,
      solemnizedBaptism: json['solemnizedBaptism'] ?? false,
      baptismDate: baptismDateRaw is Timestamp
          ? baptismDateRaw.toDate()
          : baptismDateRaw is DateTime
              ? baptismDateRaw
              : null,
      baptismCertificateNumber: json['baptismCertificateNumber'] ?? '',
      baptismChurchName: json['baptismChurchName'] ?? '',
      baptismPastorName: json['baptismPastorName'] ?? '',
      marriageSolemnizationChurchType:
          json['marriageSolemnizationChurchType'] ?? '',
      marriageSolemnizationChurchName:
          json['marriageSolemnizationChurchName'] ?? '',
      membershipCurrentStatus: json['membershipCurrentStatus'] ?? '',
      membershipNotes: json['membershipNotes'] ?? '',
      additionalNotes: json['additionalNotes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
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
