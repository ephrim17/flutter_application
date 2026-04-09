import 'package:flutter_application/church_app/models/side_drawer_models/church_transaction_model.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/screens/side_drawer/financial_dashboard_view_state.dart';
import 'package:flutter_application/church_app/services/side_drawer/financial_dashboard_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final financialTransactionsProvider =
    FutureProvider<List<ChurchTransaction>>((ref) async {
  final hasFinanceAccess = ref.watch(financeDashboardAccessProvider);
  if (!hasFinanceAccess) {
    return const <ChurchTransaction>[];
  }

  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null || churchId.trim().isEmpty) {
    return const <ChurchTransaction>[];
  }

  final repository = ref.watch(financialDashboardRepositoryProvider);
  return repository.fetchTransactions(churchId);
});

final financialDashboardViewModelProvider =
    NotifierProvider<FinancialDashboardViewModel, FinancialDashboardViewState>(
  FinancialDashboardViewModel.new,
);

class FinancialDashboardViewModel
    extends Notifier<FinancialDashboardViewState> {
  @override
  FinancialDashboardViewState build() {
    final hasFinanceAccess = ref.watch(financeDashboardAccessProvider);
    final church = ref.watch(selectedChurchProvider);
    final churchName =
        church?.name.trim().isNotEmpty == true ? church!.name.trim() : 'Church';

    ref.listen<AsyncValue<List<ChurchTransaction>>>(
      financialTransactionsProvider,
      (_, next) {
        final items = next.asData?.value;
        if (items == null) return;
        state = state.copyWith(
          transactions: items,
          visibleTransactionCount:
              FinancialDashboardViewState.defaultVisibleTransactionCount,
        );
      },
    );

    return FinancialDashboardViewState.initial(
      isAdmin: hasFinanceAccess,
      churchName: churchName,
    );
  }

  void setQuery(String value) {
    state = state.copyWith(
      query: value,
      visibleTransactionCount:
          FinancialDashboardViewState.defaultVisibleTransactionCount,
    );
  }

  void clearQuery() {
    state = state.copyWith(
      query: '',
      visibleTransactionCount:
          FinancialDashboardViewState.defaultVisibleTransactionCount,
    );
  }

  void selectType(String value) {
    state = state.copyWith(
      selectedType: value,
      visibleTransactionCount:
          FinancialDashboardViewState.defaultVisibleTransactionCount,
    );
  }

  void selectStatus(String value) {
    state = state.copyWith(
      selectedStatus: value,
      visibleTransactionCount:
          FinancialDashboardViewState.defaultVisibleTransactionCount,
    );
  }

  void selectCategory(String value) {
    state = state.copyWith(
      selectedCategory: value,
      visibleTransactionCount:
          FinancialDashboardViewState.defaultVisibleTransactionCount,
    );
  }

  void selectSortOption(TransactionSortOption value) {
    state = state.copyWith(
      sortOption: value,
      visibleTransactionCount:
          FinancialDashboardViewState.defaultVisibleTransactionCount,
    );
  }

  void showMoreTransactions() {
    state = state.copyWith(
      visibleTransactionCount: state.visibleTransactionCount +
          FinancialDashboardViewState.defaultVisibleTransactionCount,
    );
  }

  Future<void> addTransaction(ChurchTransactionFormData form) async {
    final churchId = await ref.read(currentChurchIdProvider.future);
    if (churchId == null || churchId.trim().isEmpty) {
      throw StateError('No church selected.');
    }

    state = state.copyWith(isSubmitting: true);
    try {
      await ref
          .read(financialDashboardRepositoryProvider)
          .createTransaction(churchId: churchId, form: form);
      ref.invalidate(financialTransactionsProvider);
      final items = await ref.read(financialTransactionsProvider.future);
      state = state.copyWith(
        isSubmitting: false,
        transactions: items,
        visibleTransactionCount:
            FinancialDashboardViewState.defaultVisibleTransactionCount,
      );
    } catch (_) {
      state = state.copyWith(isSubmitting: false);
      rethrow;
    }
  }

  Future<void> updateTransaction(ChurchTransactionFormData form) async {
    final churchId = await ref.read(currentChurchIdProvider.future);
    if (churchId == null || churchId.trim().isEmpty) {
      throw StateError('No church selected.');
    }

    state = state.copyWith(isSubmitting: true);
    try {
      await ref
          .read(financialDashboardRepositoryProvider)
          .updateTransaction(churchId: churchId, form: form);
      ref.invalidate(financialTransactionsProvider);
      final items = await ref.read(financialTransactionsProvider.future);
      state = state.copyWith(
        isSubmitting: false,
        transactions: items,
        visibleTransactionCount:
            FinancialDashboardViewState.defaultVisibleTransactionCount,
      );
    } catch (_) {
      state = state.copyWith(isSubmitting: false);
      rethrow;
    }
  }

  Future<void> deleteTransaction(ChurchTransaction item) async {
    final churchId = await ref.read(currentChurchIdProvider.future);
    if (churchId == null || churchId.trim().isEmpty) {
      throw StateError('No church selected.');
    }

    state = state.copyWith(isSubmitting: true);
    try {
      await ref
          .read(financialDashboardRepositoryProvider)
          .deleteTransaction(churchId: churchId, item: item);
      ref.invalidate(financialTransactionsProvider);
      final items = await ref.read(financialTransactionsProvider.future);
      state = state.copyWith(
        isSubmitting: false,
        transactions: items,
        visibleTransactionCount:
            FinancialDashboardViewState.defaultVisibleTransactionCount,
      );
    } catch (_) {
      state = state.copyWith(isSubmitting: false);
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidate(financialTransactionsProvider);
    await ref.read(financialTransactionsProvider.future);
  }
}
