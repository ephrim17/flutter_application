class SermonModel {
  final String id;
  final String url;
  final String? videoId;

  SermonModel({
    required this.id,
    required this.url,
    this.videoId,
  });

  factory SermonModel.fromFirestore(
    String id,
    Map<String, dynamic> json,
  ) {
    return SermonModel(
      id: id,
      url: json['url'],
      videoId: json['videoId'],
    );
  }
}

