import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/services/feed_repository.dart';
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
  final TextEditingController _churchSearchController = TextEditingController();
  final TextEditingController _globalSearchController = TextEditingController();
  int _selectedTabIndex = 0;
  String _churchSearchQuery = '';
  String _globalSearchQuery = '';

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
    _churchSearchController.dispose();
    _globalSearchController.dispose();
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
    final config = ref.watch(appConfigProvider).asData?.value;
    final globalFeedEnabled = config?.globalFeedEnabled ?? false;

    return churchAsync.when(
      loading: () => const Scaffold(
        body: Center(child: AppLoadingIndicator()),
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
        final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
        final isAdmin = ref.watch(isAdminProvider);
        if (!globalFeedEnabled && _selectedTabIndex > 0) {
          _selectedTabIndex = 0;
        }

        final tabCount = globalFeedEnabled ? 2 : 1;

        return DefaultTabController(
          length: tabCount,
          child: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () => _openCreatePostModal(
                context,
                churchId,
                isGlobal: globalFeedEnabled && _selectedTabIndex == 1,
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
                      isScrollable: globalFeedEnabled,
                      tabAlignment: globalFeedEnabled
                          ? TabAlignment.center
                          : TabAlignment.fill,
                      dividerColor: Colors.transparent,
                      onTap: (index) {
                        setState(() {
                          _selectedTabIndex = index;
                        });
                      },
                      tabs: [
                        const _FeedScopeTab(
                          icon: Icons.church_outlined,
                          title: 'Your Church',
                        ),
                        if (globalFeedEnabled)
                          const _FeedScopeTab(
                            icon: Icons.public_outlined,
                            title: 'Global Churches',
                          ),
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
                        currentUid: currentUid,
                        isAdmin: isAdmin,
                        searchController: _churchSearchController,
                        searchQuery: _churchSearchQuery,
                        isGlobal: false,
                      ),
                      if (globalFeedEnabled)
                        _buildBody(
                          context,
                          churchId,
                          globalFeedState,
                          currentUid: currentUid,
                          isAdmin: isAdmin,
                          searchController: _globalSearchController,
                          searchQuery: _globalSearchQuery,
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
    BuildContext context,
    String churchId,
    FeedPaginationState feedState, {
    required String? currentUid,
    required bool isAdmin,
    required TextEditingController searchController,
    required String searchQuery,
    required bool isGlobal,
  }) {
    if (feedState.isInitialLoading && feedState.posts.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }

    if (feedState.errorMessage != null && feedState.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(feedState.errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _refreshFeed(churchId, isGlobal: isGlobal),
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
        onRefresh: () => _refreshFeed(churchId, isGlobal: isGlobal),
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

    final visiblePosts = _filterPosts(feedState.posts, searchQuery);
    final itemCount = (visiblePosts.isEmpty ? 1 : visiblePosts.length) +
        (feedState.hasMore && searchQuery.trim().isEmpty ? 1 : 0) +
        1;

    return RefreshIndicator(
      onRefresh: () => _refreshFeed(churchId, isGlobal: isGlobal),
      child: ListView.builder(
        controller:
            isGlobal ? _globalScrollController : _churchScrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FeedSearchField(
              controller: searchController,
              hintText: isGlobal
                  ? 'Search global posts or #tags'
                  : 'Search church posts or #tags',
              onChanged: (value) {
                setState(() {
                  if (isGlobal) {
                    _globalSearchQuery = value;
                  } else {
                    _churchSearchQuery = value;
                  }
                });
              },
              onClear: () {
                setState(() {
                  searchController.clear();
                  if (isGlobal) {
                    _globalSearchQuery = '';
                  } else {
                    _churchSearchQuery = '';
                  }
                });
              },
            );
          }

          final postIndex = index - 1;
          if (visiblePosts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 96),
              child: Center(
                child: Text(
                  'No posts found',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }

          if (postIndex >= visiblePosts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: AppLoadingIndicator()),
            );
          }

          final post = visiblePosts[postIndex];
          return FeedCard(
            post: post,
            currentUid: currentUid,
            isAdmin: isAdmin,
            isGlobal: isGlobal,
            onHashtagTap: (tag) => _openHashtagFeed(
              context,
              tag,
              churchId: churchId,
              currentUid: currentUid,
              isAdmin: isAdmin,
              isGlobal: isGlobal,
            ),
          );
        },
      ),
    );
  }

  List<FeedPost> _filterPosts(List<FeedPost> posts, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return posts;

    final hashtag = normalized.startsWith('#')
        ? normalizeHashtag(normalized)
        : normalizeHashtag(normalized);

    return posts.where((post) {
      if (normalized.startsWith('#')) {
        return post.hashtags.contains(hashtag) ||
            extractHashtags('${post.title}\n${post.description}')
                .contains(hashtag);
      }

      final haystack = [
        post.title,
        post.description,
        post.userName,
        post.churchName ?? '',
        post.churchPastorName ?? '',
        ...post.hashtags.map((tag) => '#$tag'),
      ].join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList(growable: false);
  }

  void _openHashtagFeed(
    BuildContext context,
    String tag, {
    required String churchId,
    required String? currentUid,
    required bool isAdmin,
    required bool isGlobal,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedHashtagScreen(
          hashtag: tag,
          churchId: churchId,
          currentUid: currentUid,
          isAdmin: isAdmin,
          isGlobal: isGlobal,
        ),
      ),
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
      parameters: {
        'scope': isGlobal ? 'global' : 'church',
      },
    );
    if (!context.mounted) return;

    await showAppModalBottomSheet(
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

  Future<void> _refreshFeed(
    String churchId, {
    required bool isGlobal,
  }) async {
    if (isGlobal) {
      await ref.read(globalFeedPaginationControllerProvider.notifier).refresh();
      return;
    }

    await ref
        .read(feedPaginationControllerProvider(churchId).notifier)
        .refresh();
  }
}

class _FeedScopeTab extends StatelessWidget {
  const _FeedScopeTab({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 64,
      icon: Icon(icon, size: 22),
      iconMargin: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _FeedSearchField extends StatelessWidget {
  const _FeedSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                ),
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.24),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.24),
            ),
          ),
        ),
      ),
    );
  }
}

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
                'No posts found for #$normalizedTag',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
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
          );
        },
      ),
    );
  }
}
