import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SermonCard extends StatefulWidget {
  final String youtubeUrl;
  final VoidCallback? onTap;

  const SermonCard({
    super.key,
    required this.youtubeUrl,
    this.onTap,
  });

  @override
  State<SermonCard> createState() => _SermonCardState();
}

class _SermonCardState extends State<SermonCard> {
  late Future<_Meta> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchMeta();
  }

  Future<_Meta> _fetchMeta() async {
    final uri = Uri.parse(
      'https://www.youtube.com/oembed'
      '?url=${Uri.encodeComponent(widget.youtubeUrl)}'
      '&format=json',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to load metadata');
    }

    final json = jsonDecode(res.body);
    return _Meta(
      title: json['title'],
      thumbnail: json['thumbnail_url'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Meta>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Circular thumbnail
                  ClipOval(
                    child: Image.network(
                      data.thumbnail,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Title
                  Expanded(
                    child: Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _loading() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: const [
            CircleAvatar(radius: 32),
            SizedBox(width: 16),
            Expanded(child: LinearProgressIndicator()),
          ],
        ),
      );
}

class _Meta {
  final String title;
  final String thumbnail;

  _Meta({
    required this.title,
    required this.thumbnail,
  });
}
