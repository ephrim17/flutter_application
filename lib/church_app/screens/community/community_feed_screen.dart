import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/community_upload_provider.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:flutter_application/church_app/screens/community/community_full_screen_viewer.dart';
import 'package:flutter_application/church_app/screens/feed_screen.dart' show FeedHashtagScreen;
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/community_upload_banner.dart';
import 'package:flutter_application/church_app/widgets/feed_card_widget.dart';
import 'package:flutter_application/church_app/widgets/feed_post_modal.dart';
import 'package:flutter_application/church_app/widgets/hideable_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// LinkedIn-style feed: a plain scrollable list of post cards per segment
/// ("Your Church" / "All Churches"). Tapping a card opens the full-screen
/// swipeable viewer at that post.
class CommunityFeedScreen extends ConsumerStatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  ConsumerState<CommunityFeedScreen> createState() =>
      _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends ConsumerState<CommunityFeedScreen> {
  int _segment = 0;
  bool _appBarVisible = true;

  bool _handleScrollNotification(ScrollNotification notification) {
    return computeHideableAppBarVisibility(
      notification: notification,
      currentlyVisible: _appBarVisible,
      onChanged: (visible) => setState(() => _appBarVisible = visible),
    );
  }

  @override
  Widget build(BuildContext context) {
    final churchAsync = ref.watch(currentChurchIdProvider);
    final config = ref.watch(appConfigProvider).asData?.value;
    final globalFeedEnabled = config?.globalFeedEnabled ?? false;

    return churchAsync.when(
      loading: () => const Scaffold(
        body: Center(child: AppLoadingIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text(ref.t('feed.error_load'))),
      ),
      data: (churchId) {
        if (churchId == null) {
          return Scaffold(
            body: Center(child: Text(ref.t('feed.no_church_selected'))),
          );
        }

        if (!globalFeedEnabled && _segment != 0) {
          _segment = 0;
        }

        return Scaffold(
          body: Stack(
            children: [
              Column(
                children: [
                  HideableAppBar(
                visible: _appBarVisible,
                appBar: AppBar(
                  toolbarHeight: 64,
                  titleSpacing: 4,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: IconButton(
                    tooltip: context.t('feed.create_title'),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                    onPressed: () => _openCreatePostModal(
                      context,
                      churchId,
                      isGlobal: globalFeedEnabled && _segment == 1,
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: _SegmentTab(
                          label: ref.t('ui.feed.your_church'),
                          selected: _segment == 0,
                          onTap: () => setState(() => _segment = 0),
                        ),
                      ),
                      if (globalFeedEnabled) ...[
                        const SizedBox(width: 20),
                        Flexible(
                          child: _SegmentTab(
                            label: ref.t('ui.feed.all_churches'),
                            selected: _segment == 1,
                            onTap: () => setState(() => _segment = 1),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: IndexedStack(
                    index: _segment,
                    children: [
                      _CommunityFeedListView(
                        key: const PageStorageKey('community-church-list'),
                        churchId: churchId,
                        isGlobal: false,
                      ),
                      if (globalFeedEnabled)
                        _CommunityFeedListView(
                          key: const PageStorageKey('community-global-list'),
                          churchId: churchId,
                          isGlobal: true,
                        ),
                    ],
                  ),
                ),
              ),
                ],
              ),
              const CommunityUploadBanner(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCreatePostModal(
    BuildContext context,
    String churchId, {
    required bool isGlobal,
  }) async {
    await logChurchAnalyticsEvent(
      ref,
      name: 'feed_post_create_started',
      parameters: {'scope': isGlobal ? 'global' : 'church'},
    );
    if (!context.mounted) return;

    final pending = await Navigator.of(context).push<PendingCommunityPost?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreatePostModal(initialIsGlobal: isGlobal),
      ),
    );

    if (!mounted || pending == null) return;

    // Fire-and-forget: the composer is already closed, and the floating
    // banner (driven by the same provider) tracks progress from here.
    unawaited(
      ref
          .read(communityUploadControllerProvider.notifier)
          .submit(churchId: churchId, pending: pending),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              decoration: BoxDecoration(
                color:
                    selected ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityFeedListView extends ConsumerStatefulWidget {
  const _CommunityFeedListView({
    super.key,
    required this.churchId,
    required this.isGlobal,
  });

  final String churchId;
  final bool isGlobal;

  @override
  ConsumerState<_CommunityFeedListView> createState() =>
      _CommunityFeedListViewState();
}

class _CommunityFeedListViewState
    extends ConsumerState<_CommunityFeedListView> {
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

  FeedPaginationController _notifier() {
    return widget.isGlobal
        ? ref.read(globalFeedPaginationControllerProvider.notifier)
        : ref.read(feedPaginationControllerProvider(widget.churchId).notifier);
  }

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
        builder: (_) => CommunityFullScreenViewer(
          churchId: widget.churchId,
          initialIsGlobal: widget.isGlobal,
          initialPostId: postId,
        ),
      ),
    );
  }

  void _openHashtagFeed(
    BuildContext context,
    String tag, {
    required String? currentUid,
    required bool isAdmin,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedHashtagScreen(
          hashtag: tag,
          churchId: widget.churchId,
          currentUid: currentUid,
          isAdmin: isAdmin,
          isGlobal: widget.isGlobal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.isGlobal
        ? ref.watch(globalFeedPaginationControllerProvider)
        : ref.watch(feedPaginationControllerProvider(widget.churchId));
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
              child: Text(ref.t('feed.retry')),
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
            Center(
              child: Text(
                widget.isGlobal
                    ? context.t('ui.feed.no_global_posts')
                    : ref.t('feed.no_posts'),
              ),
            ),
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
            isGlobal: widget.isGlobal,
            onTap: () => _openFullScreenViewer(post.id),
            onHashtagTap: (tag) => _openHashtagFeed(
              context,
              tag,
              currentUid: currentUid,
              isAdmin: isAdmin,
            ),
          );
        },
      ),
    );
  }
}
