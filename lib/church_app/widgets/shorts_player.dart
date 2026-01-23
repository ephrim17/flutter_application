
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/for_you_section_model/shorts_model.dart';
import 'package:flutter_application/church_app/widgets/swipe_up_widget.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ShortsPlayerItem extends StatefulWidget {
  final ShortModel short;
  final bool showSwipeHint;

   const ShortsPlayerItem(
    this.short, {
    super.key,
    this.showSwipeHint = false,
  });

  @override
  State<ShortsPlayerItem> createState() => _ShortsPlayerItemState();
}

class _ShortsPlayerItemState extends State<ShortsPlayerItem> {
  late YoutubePlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = YoutubePlayerController(
      initialVideoId: widget.short.videoId,
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
           if (widget.showSwipeHint) const SwipeUpHint(),
        ],
    );
  }
}
