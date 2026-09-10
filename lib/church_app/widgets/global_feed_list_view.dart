import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:flutter_application/church_app/screens/community/global_feed_full_screen_viewer.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/feed_card_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The cross-church feed, inline — `SelectChurchScreen`'s main content.
/// Tapping a post opens `GlobalFeedFullScreenViewer` at that post; there is
/// no create-post action here (posting is church-scoped only, from inside
/// Community).
class GlobalFeedListView extends ConsumerStatefulWidget {
  const GlobalFeedListView({super.key});

  @override
  ConsumerState<GlobalFeedListView> createState() => _GlobalFeedListViewState();
}

class _GlobalFeedListViewState extends ConsumerState<GlobalFeedListView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  FeedPaginationController _notifier() =>
      ref.read(globalFeedPaginationControllerProvider.notifier);

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    const triggerThreshold = 400.0;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels > triggerThreshold) return;
    _notifier().loadMore();
  }

  void _openFullScreenViewer(String postId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GlobalFeedFullScreenViewer(initialPostId: postId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(globalFeedPaginationControllerProvider);
    final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isAdmin = ref.watch(isAdminProvider);

    if (state.isInitialLoading && state.posts.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }

    if (state.errorMessage != null && state.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _notifier().refresh,
              child: Text(context.t('feed.retry')),
            ),
          ],
        ),
      );
    }

    if (state.posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _notifier().refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 280),
            Center(child: Text(context.t('ui.feed.no_global_posts'))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _notifier().refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.posts.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: AppLoadingIndicator()),
            );
          }

          final post = state.posts[index];
          return FeedCard(
            key: ValueKey(post.id),
            post: post,
            currentUid: currentUid,
            isAdmin: isAdmin,
            isGlobal: true,
            onTap: () => _openFullScreenViewer(post.id),
          );
        },
      ),
    );
  }
}
