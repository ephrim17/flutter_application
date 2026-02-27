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

  Map<String, dynamic> toMap() => {
        'title': title,
        'tagline': tagline,
        'description': description,
        'mission': mission,
        'community': community,
        'values': values,
      };
  }

