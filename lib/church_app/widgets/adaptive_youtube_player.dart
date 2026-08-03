import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart' as mobile;
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as iframe;

class AdaptiveYoutubePlayer extends StatefulWidget {
  const AdaptiveYoutubePlayer({
    super.key,
    required this.videoId,
    this.autoPlay = false,
    this.isLive = false,
    this.aspectRatio = 16 / 9,
    this.showFullscreenButton = true,
    this.controller,
  });

  final String videoId;
  final bool autoPlay;
  final bool isLive;
  final double aspectRatio;
  final bool showFullscreenButton;
  final AdaptiveYoutubePlayerController? controller;

  @override
  State<AdaptiveYoutubePlayer> createState() => _AdaptiveYoutubePlayerState();
}

class AdaptiveYoutubePlayerController {
  _AdaptiveYoutubePlayerState? _state;

  void pause() => _state?._pause();
}

class AdaptiveYoutubeThumbnail extends StatelessWidget {
  const AdaptiveYoutubeThumbnail({
    super.key,
    required this.videoId,
    required this.onPlay,
  });

  final String videoId;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 16 / 9,
        child: InkWell(
          onTap: onPlay,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 160),
                placeholder: (_, __) => const Center(
                  child: AppLoadingIndicator(),
                ),
                errorWidget: (_, __, ___) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              const ColoredBox(color: Colors.black26),
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 66,
                ),
              ),
            ],
          ),
        ),
      );
}

Future<void> showAdaptiveYoutubeFullscreen(
  BuildContext context, {
  required String videoId,
  bool isLive = false,
}) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _AdaptiveYoutubeFullscreenScreen(
          videoId: videoId,
          isLive: isLive,
        ),
      ),
    );

class _AdaptiveYoutubeFullscreenScreen extends StatefulWidget {
  const _AdaptiveYoutubeFullscreenScreen({
    required this.videoId,
    required this.isLive,
  });

  final String videoId;
  final bool isLive;

  @override
  State<_AdaptiveYoutubeFullscreenScreen> createState() =>
      _AdaptiveYoutubeFullscreenScreenState();
}

class _AdaptiveYoutubeFullscreenScreenState
    extends State<_AdaptiveYoutubeFullscreenScreen> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      unawaited(
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      unawaited(
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]),
      );
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AdaptiveYoutubePlayer(
                videoId: widget.videoId,
                autoPlay: true,
                isLive: widget.isLive,
                aspectRatio: MediaQuery.sizeOf(context).aspectRatio,
                showFullscreenButton: false,
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: SafeArea(
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ],
        ),
      );
}

class _AdaptiveYoutubePlayerState extends State<AdaptiveYoutubePlayer> {
  mobile.YoutubePlayerController? _mobileController;
  iframe.YoutubePlayerController? _webController;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _createController();
  }

  @override
  void didUpdateWidget(covariant AdaptiveYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.autoPlay != widget.autoPlay ||
        oldWidget.isLive != widget.isLive ||
        oldWidget.showFullscreenButton != widget.showFullscreenButton) {
      _disposeController();
      _createController();
    }
  }

  void _createController() {
    if (kIsWeb) {
      _webController = iframe.YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: widget.autoPlay,
        params: iframe.YoutubePlayerParams(
          enableCaption: true,
          showControls: true,
          showFullscreenButton: widget.showFullscreenButton,
          strictRelatedVideos: true,
        ),
      );
      return;
    }
    _mobileController = mobile.YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: mobile.YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        enableCaption: true,
        isLive: widget.isLive,
        showLiveFullscreenButton: widget.showFullscreenButton,
      ),
    );
  }

  void _disposeController() {
    _mobileController?.dispose();
    _mobileController = null;
    final webController = _webController;
    _webController = null;
    if (webController != null) unawaited(webController.close());
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
    _disposeController();
    super.dispose();
  }

  void _pause() {
    if (kIsWeb) {
      final controller = _webController;
      if (controller != null) unawaited(controller.pauseVideo());
      return;
    }
    _mobileController?.pause();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return iframe.YoutubePlayer(
        controller: _webController!,
        aspectRatio: widget.aspectRatio,
      );
    }
    return mobile.YoutubePlayer(
      controller: _mobileController!,
      aspectRatio: widget.aspectRatio,
      showVideoProgressIndicator: true,
      progressIndicatorColor: Theme.of(context).colorScheme.primary,
    );
  }
}
