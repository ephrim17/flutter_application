import 'package:url_launcher/url_launcher.dart';

class YoutubeUtils {
  static Future<void> openYoutubeChannel(String channelId) async {
    final youtubeUrl = 'https://youtube.com/@tnbmindia?si=OajCCsgbBNwUKczO';
    final youtubeAppUrl = 'youtube://www.youtube.com/@tnbmindia?si=OajCCsgbBNwUKczO';

    if (await canLaunchUrl(Uri.parse(youtubeAppUrl))) {
      await launchUrl(Uri.parse(youtubeAppUrl));
    } else if (await canLaunchUrl(Uri.parse(youtubeUrl))) {
      await launchUrl(Uri.parse(youtubeUrl));
    } else {
      throw 'Could not launch \$youtubeUrl';
    }
  }
}
