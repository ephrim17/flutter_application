import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/feed_model.dart';
import 'package:flutter_application/church_app/services/feed_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

final feedRepositoryProvider = Provider(
  (ref) => FeedRepository(FirebaseFirestore.instance),
);

final feedPaginationControllerProvider = StateNotifierProvider.autoDispose
    .family<FeedPaginationController, FeedPaginationState, String>(
  (ref, churchId) => FeedPaginationController(
    repository: ref.read(feedRepositoryProvider),
    churchId: churchId,
    isGlobal: false,
  ),
);

final globalFeedPaginationControllerProvider = StateNotifierProvider
    .autoDispose<FeedPaginationController, FeedPaginationState>(
  (ref) => FeedPaginationController(
    repository: ref.read(feedRepositoryProvider),
    churchId: null,
    isGlobal: true,
  ),
);

class FeedPaginationController extends StateNotifier<FeedPaginationState> {
  final FeedRepository _repository;
  final String? churchId;
  final bool isGlobal;
  bool _isLoadingSearchCoverage = false;

  FeedPaginationController({
    required FeedRepository repository,
    required this.churchId,
    required this.isGlobal,
  })  : _repository = repository,
        super(const FeedPaginationState()) {
    _loadInitial();
  }

  Future<void> _loadInitial({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isInitialLoading: true, clearError: true);
    }

    try {
      final page = await _repository.fetchFeedPage(
        churchId: churchId,
        isGlobal: isGlobal,
      );
      state = state.copyWith(
        posts: page.posts,
        lastDocument: page.lastDocument,
        hasMore: page.hasMore,
        isInitialLoading: false,
      );
    } catch (e) {
      if (showLoading) {
        state = state.copyWith(
          isInitialLoading: false,
          errorMessage: e.toString(),
        );
      }
    }
  }

  Future<void> refresh() async {
    state = const FeedPaginationState(isInitialLoading: true);
    await _loadInitial();
  }

  Future<void> refreshSilently() => _loadInitial(showLoading: false);

  void setChurchPostGlobal({
    required String postId,
    required bool isGlobal,
  }) {
    state = state.copyWith(
      posts: state.posts
          .map(
            (post) =>
                post.id == postId ? post.copyWith(isGlobal: isGlobal) : post,
          )
          .toList(growable: false),
    );
  }

  void upsertPromotedPost({
    required FeedPost source,
    required String sourceChurchId,
  }) {
    final promotedId = '${sourceChurchId}_${source.id}';
    final promoted = source.copyWith(
      id: promotedId,
      isGlobal: true,
      sourceChurchId: sourceChurchId,
      sourcePostId: source.id,
      isPinned: false,
      clearPinnedAt: true,
    );
    state = state.copyWith(
      posts: sortFeedPosts([
        promoted,
        ...state.posts.where((post) => post.id != promotedId),
      ]),
    );
  }

  void removePromotedPost({
    required String sourceChurchId,
    required String sourcePostId,
  }) {
    state = state.copyWith(
      posts: state.posts
          .where(
            (post) =>
                post.sourceChurchId != sourceChurchId ||
                post.sourcePostId != sourcePostId,
          )
          .toList(growable: false),
    );
  }

  Future<void> loadMore() async {
    if (state.isInitialLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true, errorMessage: null);

    try {
      final page = await _repository.fetchFeedPage(
        churchId: churchId,
        isGlobal: isGlobal,
        startAfter: state.lastDocument,
      );

      state = state.copyWith(
        posts: [...state.posts, ...page.posts],
        lastDocument: page.lastDocument ?? state.lastDocument,
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadSearchCoverage({int maxPages = 6}) async {
    if (_isLoadingSearchCoverage) return;

    _isLoadingSearchCoverage = true;
    try {
      var loadedPages = 0;
      while (
          state.hasMore && !state.isInitialLoading && loadedPages < maxPages) {
        await loadMore();
        loadedPages += 1;
      }
    } finally {
      _isLoadingSearchCoverage = false;
    }
  }
}

class FeedPaginationState {
  final List<FeedPost> posts;
  final DocumentSnapshot? lastDocument;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;

  const FeedPaginationState({
    this.posts = const [],
    this.lastDocument,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
  });

  FeedPaginationState copyWith({
    List<FeedPost>? posts,
    DocumentSnapshot? lastDocument,
    bool clearLastDocument = false,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FeedPaginationState(
      posts: posts ?? this.posts,
      lastDocument:
          clearLastDocument ? null : (lastDocument ?? this.lastDocument),
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
