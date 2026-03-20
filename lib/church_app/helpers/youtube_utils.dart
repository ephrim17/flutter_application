import 'package:url_launcher/url_launcher.dart';

class YoutubeUtils {
  static const String _fallbackYoutubeUrl = 'https://www.youtube.com/@YouTube';
  static const String _fallbackYoutubeAppUrl =
      'youtube://www.youtube.com/@YouTube';

  static Future<void> openYoutubeChannel([String? youtubeLink]) async {
    final youtubeUrl = _normalizedYoutubeUrl(youtubeLink);
    final youtubeAppUrl = _buildYoutubeAppUrl(youtubeLink);

    if (await canLaunchUrl(Uri.parse(youtubeAppUrl))) {
      await launchUrl(Uri.parse(youtubeAppUrl));
    } else if (await canLaunchUrl(Uri.parse(youtubeUrl))) {
      await launchUrl(Uri.parse(youtubeUrl));
    } else {
      throw 'Could not launch \$youtubeUrl';
    }
  }

  static String _normalizedYoutubeUrl(String? youtubeLink) {
    final trimmed = youtubeLink?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _fallbackYoutubeUrl;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return _fallbackYoutubeUrl;
    }

    if (uri.hasScheme) {
      return trimmed;
    }

    return 'https://$trimmed';
  }

  static String _buildYoutubeAppUrl(String? youtubeLink) {
    final normalizedUrl = _normalizedYoutubeUrl(youtubeLink);
    if (normalizedUrl == _fallbackYoutubeUrl) {
      return _fallbackYoutubeAppUrl;
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      return _fallbackYoutubeAppUrl;
    }

    final path = uri.path.isEmpty ? '' : uri.path;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return 'youtube://www.youtube.com$path$query';
  }
}
