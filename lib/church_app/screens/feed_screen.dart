import 'package:flutter/material.dart';
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
  final ScrollController _scrollController = ScrollController();

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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    const triggerThreshold = 300.0;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels <= triggerThreshold) {
      final churchId = ref.read(currentChurchIdProvider).value;
      if (churchId == null) return;
      ref
          .read(feedPaginationControllerProvider(churchId).notifier)
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final churchAsync = ref.watch(currentChurchIdProvider);

    return churchAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const Scaffold(
        body: Center(child: Text('Unable to load feed')),
      ),
      data: (churchId) {
        if (churchId == null) {
          return const Scaffold(
            body: Center(child: Text('No church selected')),
          );
        }

        final feedState = ref.watch(feedPaginationControllerProvider(churchId));

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openCreatePostModal(context, churchId),
            child: const Icon(Icons.add),
          ),
          body: _buildBody(context, churchId, feedState),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    String churchId,
    FeedPaginationState feedState,
  ) {
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
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (feedState.posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(feedPaginationControllerProvider(churchId).notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 280),
            Center(child: Text("No posts yet")),
          ],
        ),
      );
    }

    final itemCount = feedState.posts.length + (feedState.hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(feedPaginationControllerProvider(churchId).notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
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
          return FeedCard(post: post);
        },
      ),
    );
  }

  Future<void> _openCreatePostModal(BuildContext context, String churchId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.95,
        child: const CreatePostModal(),
      ),
    );

    if (!mounted) return;
    await ref.read(feedPaginationControllerProvider(churchId).notifier).refresh();
  }
}
