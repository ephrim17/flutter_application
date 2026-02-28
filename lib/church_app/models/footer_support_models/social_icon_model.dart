class SocialIconModel {
  final String id;
  final String icon;
  final String url;
  final int order;
  final bool isActive;

  SocialIconModel({
    required this.id,
    required this.icon,
    required this.url,
    required this.order,
    required this.isActive,
  });

  factory SocialIconModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return SocialIconModel(
      id: id,
      icon: data['icon'] ?? '',
      url: data['url'] ?? '',
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'icon': icon,
      'url': url,
      'order': order,
      'isActive': isActive,
    };
  }
}