import 'package:flutter_application/church_app/helpers/feed_link_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedLinkUtils.youtubePreviewFromText', () {
    const videoId = 'dQw4w9WgXcQ';

    test('extracts video ids from common mobile and web YouTube links', () {
      final links = [
        'https://www.youtube.com/watch?v=$videoId',
        'https://m.youtube.com/watch?v=$videoId&feature=shared',
        'https://youtube.com/watch?v=$videoId&si=abc123',
        'https://youtu.be/$videoId?si=abc123',
        'youtu.be/$videoId',
        'www.youtube.com/shorts/$videoId?feature=share',
        'https://youtube.com/live/$videoId?si=abc123',
        'https://www.youtube.com/embed/$videoId',
      ];

      for (final link in links) {
        final preview = FeedLinkUtils.youtubePreviewFromText('Watch $link');

        expect(preview?.videoId, videoId, reason: link);
      }
    });
  });

  group('FeedLinkUtils.linkMatches', () {
    test('keeps normal links tappable without trailing punctuation', () {
      final match = FeedLinkUtils.linkMatches(
        'Visit example.com/path?from=feed.',
      ).single;

      expect(match.linkText, 'example.com/path?from=feed');
      expect(match.trailingText, '.');
      expect(match.uri.toString(), 'https://example.com/path?from=feed');
    });
  });
}
