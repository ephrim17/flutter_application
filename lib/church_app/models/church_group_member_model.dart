class ChurchGroupMember {
  const ChurchGroupMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.category,
    required this.groupId,
    required this.groupLabel,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String category;
  final String groupId;
  final String groupLabel;

  factory ChurchGroupMember.fromMap(Map<String, dynamic> data) {
    return ChurchGroupMember(
      uid: (data['uid'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      groupId: (data['groupId'] ?? '').toString(),
      groupLabel: (data['groupLabel'] ?? '').toString(),
    );
  }
}
