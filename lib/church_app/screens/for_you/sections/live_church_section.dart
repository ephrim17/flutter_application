import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/contact_launcher.dart';
import 'package:flutter_application/church_app/models/live_church_model.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/live_church_provider.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/adaptive_youtube_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _playerController = AdaptiveYoutubePlayerController();

  @override
  Widget build(BuildContext context) {
    if (!widget.status.canEmbed) {
      return _buildCard(
        context,
        _YouTubeFallback(videoId: widget.status.videoId),
      );
    }
    return _buildCard(
      context,
      AdaptiveYoutubePlayer(
        key: ValueKey(widget.status.videoId),
        videoId: widget.status.videoId,
        isLive: true,
        showFullscreenButton: false,
        controller: _playerController,
      ),
    );
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

  Future<void> _openFullscreen() async {
    _playerController.pause();
    await showAdaptiveYoutubeFullscreen(
      context,
      videoId: widget.status.videoId,
      isLive: true,
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
            onPressed: () => launchExternalUri(
              context,
              Uri.parse('https://www.youtube.com/watch?v=$videoId'),
              failureMessage: context.t('common.open_link_failed'),
            ),
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
