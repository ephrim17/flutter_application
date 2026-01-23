
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/for_you_section_model/sermon_model.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class SermonPlayer extends StatefulWidget {
  final SermonModel sermon;
   const SermonPlayer(
    this.sermon, {
    super.key,
  });

  @override
  State<SermonPlayer> createState() => SermonPlayerState();
}

class SermonPlayerState extends State<SermonPlayer> {
  late YoutubePlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = YoutubePlayerController(
      initialVideoId: widget.sermon.videoId ?? YoutubePlayer.convertUrlToId(widget.sermon.url) ?? '',
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: true,
        controlsVisibleAtStart: false,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: YoutubePlayer(
                controller: controller,
                showVideoProgressIndicator: false,
                ),
              ),
            ),
          ),
        ],
    );
  }
}