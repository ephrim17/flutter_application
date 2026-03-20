import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:flutter_application/church_app/widgets/feed_card_widget.dart';
import 'package:flutter_application/church_app/widgets/feed_post_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final ScrollController _churchScrollController = ScrollController();
  final ScrollController _globalScrollController = ScrollController();
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _churchScrollController.addListener(_onChurchScroll);
    _globalScrollController.addListener(_onGlobalScroll);
  }

  @override
  void dispose() {
    _churchScrollController.removeListener(_onChurchScroll);
    _globalScrollController.removeListener(_onGlobalScroll);
    _churchScrollController.dispose();
    _globalScrollController.dispose();
    super.dispose();
  }

  void _onChurchScroll() {
    if (!_churchScrollController.hasClients) return;
    const triggerThreshold = 300.0;
    final position = _churchScrollController.position;
    if (position.maxScrollExtent - position.pixels > triggerThreshold) return;

    final churchId = ref.read(currentChurchIdProvider).value;
    if (churchId == null) return;
    ref.read(feedPaginationControllerProvider(churchId).notifier).loadMore();
  }

  void _onGlobalScroll() {
    if (!_globalScrollController.hasClients) return;
    const triggerThreshold = 300.0;
    final position = _globalScrollController.position;
    if (position.maxScrollExtent - position.pixels > triggerThreshold) return;

    ref.read(globalFeedPaginationControllerProvider.notifier).loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final churchAsync = ref.watch(currentChurchIdProvider);

    return churchAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text(
            ref.t('feed.error_load', fallback: 'Unable to load feed'),
          ),
        ),
      ),
      data: (churchId) {
        if (churchId == null) {
          return Scaffold(
            body: Center(
              child: Text(
                ref.t(
                  'feed.no_church_selected',
                  fallback: 'No church selected',
                ),
              ),
            ),
          );
        }

        final feedState = ref.watch(feedPaginationControllerProvider(churchId));
        final globalFeedState =
            ref.watch(globalFeedPaginationControllerProvider);

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () => _openCreatePostModal(
                context,
                churchId,
                isGlobal: _selectedTabIndex == 1,
              ),
              child: const Icon(Icons.add),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Container(
                    decoration: carouselBoxDecoration(context),
                    child: TabBar(
                      dividerColor: Colors.transparent,
                      onTap: (index) {
                        setState(() {
                          _selectedTabIndex = index;
                        });
                      },
                      tabs: const [
                        Tab(text: 'Church'),
                        Tab(text: 'Global'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildBody(
                        context,
                        churchId,
                        feedState,
                        isGlobal: false,
                      ),
                      _buildBody(
                        context,
                        churchId,
                        globalFeedState,
                        isGlobal: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
      BuildContext context, String churchId, FeedPaginationState feedState,
      {required bool isGlobal}) {
    if (feedState.isInitialLoading && feedState.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (feedState.errorMessage != null && feedState.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(feedState.errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref
                  .read(feedPaginationControllerProvider(churchId).notifier)
                  .refresh(),
              child: Text(
                ref.t('feed.retry', fallback: 'Retry'),
              ),
            ),
          ],
        ),
      );
    }

    if (feedState.posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref
            .read(feedPaginationControllerProvider(churchId).notifier)
            .refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 280),
            Center(
              child: Text(
                isGlobal
                    ? 'No global posts yet'
                    : ref.t('feed.no_posts', fallback: 'No posts yet'),
              ),
            ),
          ],
        ),
      );
    }

    final itemCount = feedState.posts.length + (feedState.hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () => ref
          .read(feedPaginationControllerProvider(churchId).notifier)
          .refresh(),
      child: ListView.builder(
        controller:
            isGlobal ? _globalScrollController : _churchScrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= feedState.posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final post = feedState.posts[index];
          return FeedCard(
            post: post,
            isGlobal: isGlobal,
          );
        },
      ),
    );
  }

  Future<void> _openCreatePostModal(
    BuildContext context,
    String churchId, {
    required bool isGlobal,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.95,
        child: CreatePostModal(isGlobal: isGlobal),
      ),
    );

    if (!mounted) return;
    if (isGlobal) {
      await ref.read(globalFeedPaginationControllerProvider.notifier).refresh();
      return;
    }

    await ref
        .read(feedPaginationControllerProvider(churchId).notifier)
        .refresh();
  }
}
