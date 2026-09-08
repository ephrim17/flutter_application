import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:flutter_application/church_app/services/feed_repository.dart';
import 'package:flutter_application/church_app/widgets/feed_card_widget.dart';
import 'package:flutter_application/church_app/widgets/feed_scroll_navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedHashtagScreen extends ConsumerStatefulWidget {
  const FeedHashtagScreen({
    super.key,
    required this.hashtag,
    required this.churchId,
    required this.currentUid,
    required this.isAdmin,
    required this.isGlobal,
  });

  final String hashtag;
  final String churchId;
  final String? currentUid;
  final bool isAdmin;
  final bool isGlobal;

  @override
  ConsumerState<FeedHashtagScreen> createState() => _FeedHashtagScreenState();
}

class _FeedHashtagScreenState extends ConsumerState<FeedHashtagScreen> {
  late Future<List<FeedPost>> _postsFuture;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _postsFuture = _loadPosts();
  }

  Future<List<FeedPost>> _loadPosts() {
    return ref.read(feedRepositoryProvider).fetchPostsByHashtag(
          hashtag: widget.hashtag,
          churchId: widget.churchId,
          isGlobal: widget.isGlobal,
        );
  }

  void _refresh() {
    setState(() {
      _postsFuture = _loadPosts();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedTag = normalizeHashtag(widget.hashtag);
    return Scaffold(
      appBar: AppBar(
        title: Text('#$normalizedTag'),
      ),
      body: FutureBuilder<List<FeedPost>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: AppLoadingIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final posts = snapshot.data ?? const <FeedPost>[];
          if (posts.isEmpty) {
            return Center(
              child: Text(
                context.t(
                  'feed.no_hashtag_posts',
                  parameters: {'tag': normalizedTag},
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return FeedCard(
                      post: post,
                      currentUid: widget.currentUid,
                      isAdmin: widget.isAdmin,
                      isGlobal: widget.isGlobal,
                      onPostChanged: _refresh,
                      onHashtagTap: (tag) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => FeedHashtagScreen(
                              hashtag: tag,
                              churchId: widget.churchId,
                              currentUid: widget.currentUid,
                              isAdmin: widget.isAdmin,
                              isGlobal: widget.isGlobal,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (posts.length > 1)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FeedScrollNavigation(
                    controller: _scrollController,
                    latestLabel: ref.t('feed.jump_latest'),
                    olderLabel: ref.t('feed.jump_older'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
