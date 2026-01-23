import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class YoutubePreviewCard extends StatefulWidget {
  final String youtubeUrl;
  final VoidCallback? onTap;

  const YoutubePreviewCard({
    super.key,
    required this.youtubeUrl,
    this.onTap,
  });

  @override
  State<YoutubePreviewCard> createState() => _YoutubePreviewCardState();
}

class _YoutubePreviewCardState extends State<YoutubePreviewCard> {
  late Future<_YoutubeMeta> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchMeta();
  }

  Future<_YoutubeMeta> _fetchMeta() async {
    final uri = Uri.parse(
      'https://www.youtube.com/oembed'
      '?url=${Uri.encodeComponent(widget.youtubeUrl)}'
      '&format=json',
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load YouTube metadata');
    }

    final json = jsonDecode(res.body);
    return _YoutubeMeta(
      title: json['title'],
      thumbnail: json['thumbnail_url'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_YoutubeMeta>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }

        if (snapshot.hasError) {
          return _error();
        }

        final data = snapshot.data!;
        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      data.thumbnail,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.all(12),
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
        );
      },
    );
  }

  Widget _loading() => Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );

  Widget _error() => Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.error, color: Colors.red),
        ),
      );
}

class _YoutubeMeta {
  final String title;
  final String thumbnail;

  _YoutubeMeta({
    required this.title,
    required this.thumbnail,
  });
}

class YoutubeWebViewPlayer extends StatefulWidget {
  final String videoUrl;
  final String? title;

  const YoutubeWebViewPlayer({
    super.key,
    required this.videoUrl,
    this.title,
  });

  @override
  State<YoutubeWebViewPlayer> createState() => _YoutubeWebViewPlayerState();
}

class _YoutubeWebViewPlayerState extends State<YoutubeWebViewPlayer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(Uri.parse(_embedUrl(widget.videoUrl)));
  }

  String _embedUrl(String url) {
    final videoId = Uri.parse(url).queryParameters['v'] ??
        url.split('/').last.split('?').first;

    return 'https://www.youtube.com/embed/$videoId?autoplay=1&playsinline=1';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title ?? 'Sermon'),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
