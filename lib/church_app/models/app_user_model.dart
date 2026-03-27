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
  final bool approved;

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
  });

  factory AppUser.fromFirestore(
    String uid,
    Map<String, dynamic> data,
  ) {
    final dobRaw = data['dob'];
    final weddingDayRaw = data['weddingDay'];
    final createdAtRaw = data['createdAt'];

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
      role: data['role'] ?? 'user',
      approved: data['approved'] ?? false,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final dobRaw = json['dob'];
    final weddingDayRaw = json['weddingDay'];
    final createdAtRaw = json['createdAt'];

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
      role: json['role'] ?? 'user',
      approved: json['approved'] ?? false,
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
    };
  }
}
