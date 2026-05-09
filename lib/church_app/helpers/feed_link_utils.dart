class FeedLinkMatch {
  const FeedLinkMatch({
    required this.start,
    required this.end,
    required this.rawText,
    required this.linkText,
    required this.trailingText,
    required this.uri,
  });

  final int start;
  final int end;
  final String rawText;
  final String linkText;
  final String trailingText;
  final Uri uri;
}

class YoutubePreviewData {
  const YoutubePreviewData({
    required this.url,
    required this.videoId,
  });

  final Uri url;
  final String videoId;

  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
}

class FeedLinkUtils {
  static final RegExp _urlPattern = RegExp(
    r'((https?:\/\/|www\.)[^\s]+|(?:[a-z0-9-]+\.)+[a-z]{2,}(?:\/[^\s]*)?)',
    caseSensitive: false,
  );

  static bool hasLinks(String text) => _urlPattern.hasMatch(text);

  static Iterable<FeedLinkMatch> linkMatches(String text) sync* {
    for (final match in _urlPattern.allMatches(text)) {
      final rawText = match.group(0) ?? '';
      final linkText = cleanUrl(rawText);
      final uri = normalizeUri(linkText);
      if (linkText.isEmpty || uri == null) continue;

      yield FeedLinkMatch(
        start: match.start,
        end: match.end,
        rawText: rawText,
        linkText: linkText,
        trailingText: rawText.substring(linkText.length),
        uri: uri,
      );
    }
  }

  static YoutubePreviewData? youtubePreviewFromText(String text) {
    for (final match in linkMatches(text)) {
      final videoId = extractYoutubeVideoId(match.uri);
      if (videoId == null) continue;
      return YoutubePreviewData(url: match.uri, videoId: videoId);
    }
    return null;
  }

  static String cleanUrl(String rawUrl) {
    return rawUrl.trim().replaceAll(RegExp(r'[),.!?;:]+$'), '');
  }

  static Uri? normalizeUri(String rawUrl) {
    final normalized = rawUrl.trim();
    if (normalized.isEmpty) return null;

    final withScheme =
        normalized.startsWith('http://') || normalized.startsWith('https://')
            ? normalized
            : 'https://$normalized';
    return Uri.tryParse(withScheme);
  }

  static String? extractYoutubeVideoId(Uri uri) {
    final host = uri.host.toLowerCase();
    final normalizedHost =
        host.startsWith('www.') ? host.substring('www.'.length) : host;

    if (normalizedHost == 'youtu.be') {
      return _normalizeVideoId(
        uri.pathSegments.isEmpty ? '' : uri.pathSegments.first,
      );
    }

    if (!_isYoutubeHost(normalizedHost)) return null;

    final watchId = uri.queryParameters['v'];
    if (watchId != null) return _normalizeVideoId(watchId);

    if (uri.pathSegments.length < 2) return null;
    final route = uri.pathSegments.first.toLowerCase();
    if (route == 'shorts' ||
        route == 'embed' ||
        route == 'live' ||
        route == 'v') {
      return _normalizeVideoId(uri.pathSegments[1]);
    }

    return null;
  }

  static bool _isYoutubeHost(String host) {
    return host == 'youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'music.youtube.com' ||
        host == 'youtube-nocookie.com';
  }

  static String? _normalizeVideoId(String value) {
    final match = RegExp(r'^[A-Za-z0-9_-]{11}$').firstMatch(value.trim());
    return match?.group(0);
  }
}
