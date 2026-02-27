import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String authToken;
  final DateTime? dob;
  final bool approved;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.approved,
    required this.phone,
    required this.authToken,
    required this.dob,
  });

  factory AppUser.fromFirestore(
    String uid,
    Map<String, dynamic> data,
  ) {
    final dobRaw = data['dob'];

    return AppUser(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      authToken: data['authToken'] ?? '',
      dob: dobRaw is Timestamp
          ? dobRaw.toDate()
          : dobRaw is DateTime
              ? dobRaw
              : null,
      role: data['role'] ?? 'user',
      approved: data['approved'] ?? false,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final dobRaw = json['dob'];

    return AppUser(
      uid: json['uid'] ?? '',
      phone: json['phone'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      authToken: json['authToken'] ?? '',
      dob: dobRaw is Timestamp
          ? dobRaw.toDate()
          : dobRaw is DateTime
              ? dobRaw
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
      'role': role,
      'authToken': authToken,
      'approved': approved,
      'dob': dob != null ? Timestamp.fromDate(dob!) : null,
    };
  }
}
