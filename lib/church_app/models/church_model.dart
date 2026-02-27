class Church {
  final String id;
  final String name;
  final bool enabled;

  Church({
    required this.id,
    required this.name,
    required this.enabled,
  });

  factory Church.fromFirestore(String id, Map<String, dynamic> data) {
    return Church(
      id: id,
      name: data['name'] ?? '',
      enabled: data['enabled'] ?? false,
    );
  }
}