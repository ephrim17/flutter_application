class AboutModel {
  final String title;
  final String tagline;
  final String description;
  final String mission;
  final String community;
  final String values;

  AboutModel({
    required this.title,
    required this.tagline,
    required this.description,
    required this.mission,
    required this.community,
    required this.values,
  });

  factory AboutModel.fromFirestore(Map<String, dynamic> data) {
    return AboutModel(
      title: data['title'] ?? '',
      tagline: data['tagline'] ?? '',
      description: data['description'] ?? '',
      mission: data['mission'] ?? '',
      community: data['community'] ?? '',
      values: data['values'] ?? '',
    );
  }
}
