import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/live_church_model.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/live_church_provider.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class LiveChurchSection implements MasterSection {
  const LiveChurchSection();

  @override
  String get id => 'liveChurch';

  @override
  int get order => 5;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    return const [
      SliverToBoxAdapter(child: _LiveChurchSectionBody()),
    ];
  }
}

class _LiveChurchSectionBody extends ConsumerWidget {
  const _LiveChurchSectionBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(liveChurchStatusProvider).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (status) => status.canPlay
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _LiveChurchCard(status: status),
                )
              : const SizedBox.shrink(),
        );
  }
}

class _LiveChurchCard extends StatefulWidget {
  const _LiveChurchCard({required this.status});

  final LiveChurchStatus status;

  @override
  State<_LiveChurchCard> createState() => _LiveChurchCardState();
}

class _LiveChurchCardState extends State<_LiveChurchCard> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController(widget.status.videoId);
  }

  @override
  void didUpdateWidget(covariant _LiveChurchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status.videoId != widget.status.videoId) {
      _controller.dispose();
      _controller = _createController(widget.status.videoId);
    }
  }

  YoutubePlayerController _createController(String videoId) {
    return YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
        isLive: true,
        showLiveFullscreenButton: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.status.canEmbed) {
      return _buildCard(
        context,
        _YouTubeFallback(videoId: widget.status.videoId),
      );
    }

    final player = YoutubePlayer(
      controller: _controller,
      showVideoProgressIndicator: true,
      progressIndicatorColor: theme.colorScheme.primary,
    );
    return _buildCard(context, player);
  }

  Widget _buildCard(BuildContext context, Widget videoContent) {
    final theme = Theme.of(context);
    final title = widget.status.title.trim();
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.t('for_you.live_church.live'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onError,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t('for_you.live_church.title'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (widget.status.canEmbed)
                  IconButton(
                    tooltip: context.t('ui.live_church_section.full_screen'),
                    onPressed: _openFullscreen,
                    icon: const Icon(Icons.fullscreen_rounded),
                  ),
              ],
            ),
          ),
          videoContent,
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openFullscreen() {
    _controller.pause();
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _LiveChurchFullscreenPage(
          videoId: widget.status.videoId,
        ),
      ),
    );
  }
}

class _LiveChurchFullscreenPage extends StatefulWidget {
  const _LiveChurchFullscreenPage({required this.videoId});

  final String videoId;

  @override
  State<_LiveChurchFullscreenPage> createState() =>
      _LiveChurchFullscreenPageState();
}

class _LiveChurchFullscreenPageState extends State<_LiveChurchFullscreenPage> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        enableCaption: true,
        isLive: true,
        showLiveFullscreenButton: false,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: YoutubePlayer(
              controller: _controller,
              aspectRatio: MediaQuery.sizeOf(context).aspectRatio,
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: IconButton.filledTonal(
                tooltip: context.t('ui.live_church_section.close_full_screen'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YouTubeFallback extends StatelessWidget {
  const _YouTubeFallback({required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Icon(
            Icons.ondemand_video_rounded,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            context.t('for_you.live_church.youtube_only'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              launchUrl(
                Uri.parse('https://www.youtube.com/watch?v=$videoId'),
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(
              context.t('for_you.live_church.watch_youtube'),
            ),
          ),
        ],
      ),
    );
  }
}
