import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/date_formatter.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/community_upload_provider.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:flutter_application/church_app/screens/feed_screen.dart'
    show FeedHashtagScreen;
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_profile_avatar.dart';
import 'package:flutter_application/church_app/widgets/community_upload_banner.dart';
import 'package:flutter_application/church_app/widgets/feed_card_widget.dart';
import 'package:flutter_application/church_app/widgets/feed_post_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Instagram-Reels-style immersive viewer reached by tapping a post in
/// the LinkedIn-style Community list — full-bleed, swipe to move between
/// posts, starting at whichever post was tapped. Keeps the same
/// back / segments / create top bar visible throughout, so switching
/// audience or starting a new post doesn't require leaving the viewer.
class CommunityFullScreenViewer extends ConsumerStatefulWidget {
  const CommunityFullScreenViewer({
    super.key,
    required this.churchId,
    required this.initialIsGlobal,
    required this.initialPostId,
  });

  final String churchId;
  final bool initialIsGlobal;
  final String initialPostId;

  @override
  ConsumerState<CommunityFullScreenViewer> createState() =>
      _CommunityFullScreenViewerState();
}

class _CommunityFullScreenViewerState
    extends ConsumerState<CommunityFullScreenViewer> {
  late bool _isGlobal = widget.initialIsGlobal;

  @override
  Widget build(BuildContext context) {
    final globalFeedEnabled =
        ref.watch(appConfigProvider).value?.globalFeedEnabled ?? false;
    if (!globalFeedEnabled && _isGlobal) {
      _isGlobal = false;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildTopBar(globalFeedEnabled),
                  Expanded(
                    child: IndexedStack(
                      index: _isGlobal ? 1 : 0,
                      children: [
                        CommunityViewerPageView(
                          key: const PageStorageKey('viewer-church'),
                          churchId: widget.churchId,
                          isGlobal: false,
                          initialPostId: !widget.initialIsGlobal
                              ? widget.initialPostId
                              : null,
                        ),
                        if (globalFeedEnabled)
                          CommunityViewerPageView(
                            key: const PageStorageKey('viewer-global'),
                            churchId: widget.churchId,
                            isGlobal: true,
                            initialPostId: widget.initialIsGlobal
                                ? widget.initialPostId
                                : null,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const CommunityUploadBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool globalFeedEnabled) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: _ViewerSegmentTab(
                    label: ref.t('ui.feed.your_church'),
                    selected: !_isGlobal,
                    onTap: () => setState(() => _isGlobal = false),
                  ),
                ),
                if (globalFeedEnabled) ...[
                  const SizedBox(width: 20),
                  Flexible(
                    child: _ViewerSegmentTab(
                      label: ref.t('ui.feed.all_churches'),
                      selected: _isGlobal,
                      onTap: () => setState(() => _isGlobal = true),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: Colors.white),
            tooltip: ref.t('feed.create_title'),
            onPressed: () => _openCreatePostModal(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreatePostModal(BuildContext context) async {
    final pending = await Navigator.of(context).push<PendingCommunityPost?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreatePostModal(initialIsGlobal: _isGlobal),
      ),
    );
    if (!mounted || pending == null) return;

    // Fire-and-forget: the composer is already closed, and the floating
    // banner (driven by the same provider) tracks progress from here.
    unawaited(
      ref
          .read(communityUploadControllerProvider.notifier)
          .submit(churchId: widget.churchId, pending: pending),
    );
  }
}

class _ViewerSegmentTab extends StatelessWidget {
  const _ViewerSegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.65),
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              fontSize: 17,
              shadows: const [
                Shadow(color: Colors.black87, blurRadius: 10),
                Shadow(color: Colors.black54, blurRadius: 2),
              ],
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 2.5,
            width: selected ? 20 : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class CommunityViewerPageView extends ConsumerStatefulWidget {
  const CommunityViewerPageView({
    super.key,
    required this.churchId,
    required this.isGlobal,
    required this.initialPostId,
  });

  final String churchId;
  final bool isGlobal;
  final String? initialPostId;

  @override
  ConsumerState<CommunityViewerPageView> createState() =>
      CommunityViewerPageViewState();
}

class CommunityViewerPageViewState
    extends ConsumerState<CommunityViewerPageView> {
  PageController? _pageController;

  FeedPaginationController _notifier() {
    return widget.isGlobal
        ? ref.read(globalFeedPaginationControllerProvider.notifier)
        : ref.read(feedPaginationControllerProvider(widget.churchId).notifier);
  }

  void _onPageChanged(int index, FeedPaginationState state) {
    if (state.hasMore &&
        !state.isLoadingMore &&
        index >= state.posts.length - 3) {
      _notifier().loadMore();
    }
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

  // Caption-only for now — no likes/comments here, just the full text a
  // full-bleed post's caption can't fit in two lines.
  Future<void> _showFullCaption(BuildContext context, FeedPost post) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          final theme = Theme.of(context);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppProfileAvatar(
                              name: post.userName,
                              imageUrl: post.userPhoto,
                              radius: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                post.userName,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (post.title.trim().isNotEmpty) ...[
                          Text(
                            post.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700, height: 1.25),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (post.description.trim().isNotEmpty)
                          Text(
                            post.description,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(height: 1.5),
                          ),
                        const SizedBox(height: 18),
                        Text(
                          humanFormatDate(post.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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

    if (state.posts.isEmpty) {
      return Center(
        child: Text(
          widget.isGlobal
              ? context.t('ui.feed.no_global_posts')
              : ref.t('feed.no_posts'),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    if (_pageController == null) {
      final startIndex = widget.initialPostId == null
          ? 0
          : state.posts.indexWhere((post) => post.id == widget.initialPostId);
      _pageController =
          PageController(initialPage: startIndex < 0 ? 0 : startIndex);
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: state.posts.length,
      onPageChanged: (index) => _onPageChanged(index, state),
      itemBuilder: (context, index) {
        final post = state.posts[index];
        return FeedCard(
          key: ValueKey(post.id),
          post: post,
          currentUid: currentUid,
          isAdmin: isAdmin,
          isGlobal: widget.isGlobal,
          fullBleed: true,
          onHashtagTap: (tag) => _openHashtagFeed(
            context,
            tag,
            currentUid: currentUid,
            isAdmin: isAdmin,
          ),
          onDescriptionTap: () => _showFullCaption(context, post),
        );
      },
    );
  }
}
