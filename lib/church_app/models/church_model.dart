class Church {
  final String id;
  final String name;
  final String address;
  final String contact;
  final String email;
  final String pastorName;
  final String pastorPhoto;
  final String logo;
  final bool enabled;
  final String registrationSource;
  final String facebookLink;
  final String instagramLink;
  final String youtubeLink;

  Church({
    required this.id,
    required this.name,
    required this.address,
    required this.contact,
    required this.email,
    required this.pastorName,
    required this.pastorPhoto,
    required this.logo,
    required this.enabled,
    required this.registrationSource,
    this.facebookLink = '',
    this.instagramLink = '',
    this.youtubeLink = '',
  });

  bool get hasAnySocialLinks =>
      facebookLink.trim().isNotEmpty ||
      instagramLink.trim().isNotEmpty ||
      youtubeLink.trim().isNotEmpty;

  factory Church.fromFirestore(String id, Map<String, dynamic> data) {
    return Church(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      contact: data['contact'] ?? '',
      email: data['email'] ?? '',
      pastorName: data['pastorName'] ?? '',
      pastorPhoto: data['pastorPhoto'] ?? '',
      logo: data['logo'] ?? data['logoUrl'] ?? data['imageUrl'] ?? '',
      enabled: data['enabled'] ?? false,
      registrationSource: data['registrationSource'] ?? 'super_admin',
      facebookLink: data['facebookLink'] ?? '',
      instagramLink: data['instagramLink'] ?? '',
      youtubeLink: data['youtubeLink'] ?? '',
    );
  }
}
