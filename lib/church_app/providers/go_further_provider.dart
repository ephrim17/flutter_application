import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/services/church_repository.dart';
import 'package:hooks_riverpod/legacy.dart';

final goFurtherPaginationControllerProvider = StateNotifierProvider.autoDispose<
    GoFurtherPaginationController, GoFurtherPaginationState>(
  (ref) => GoFurtherPaginationController(
    repository: ref.read(churchRepositoryProvider),
  ),
);

class GoFurtherPaginationController
    extends StateNotifier<GoFurtherPaginationState> {
  GoFurtherPaginationController({
    required ChurchRepository repository,
  })  : _repository = repository,
        super(const GoFurtherPaginationState()) {
    _loadInitial();
  }

  final ChurchRepository _repository;

  Future<void> _loadInitial() async {
    state = state.copyWith(isInitialLoading: true, errorMessage: null);

    try {
      final page = await _repository.fetchChurchPage();
      state = state.copyWith(
        churches: page.churches,
        lastDocument: page.lastDocument,
        hasMore: page.hasMore,
        isInitialLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isInitialLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = const GoFurtherPaginationState(isInitialLoading: true);
    await _loadInitial();
  }

  Future<void> loadMore() async {
    if (state.isInitialLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, errorMessage: null);

    try {
      final page = await _repository.fetchChurchPage(
        startAfter: state.lastDocument,
      );

      state = state.copyWith(
        churches: [...state.churches, ...page.churches],
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
}

class GoFurtherPaginationState {
  const GoFurtherPaginationState({
    this.churches = const [],
    this.lastDocument,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
  });

  final List<Church> churches;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;

  GoFurtherPaginationState copyWith({
    List<Church>? churches,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
  }) {
    return GoFurtherPaginationState(
      churches: churches ?? this.churches,
      lastDocument: lastDocument ?? this.lastDocument,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
