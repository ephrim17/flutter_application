import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/input_validators.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/church_transaction_model.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/side_drawer/financial_dashboard_view_state.dart';
import 'package:flutter_application/church_app/screens/side_drawer/financial_dashboard_viewmodel.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_profile_avatar.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class FinancialDashboardScreen extends ConsumerStatefulWidget {
  const FinancialDashboardScreen({super.key});

  @override
  ConsumerState<FinancialDashboardScreen> createState() =>
      _FinancialDashboardScreenState();
}

class _FinancialDashboardScreenState
    extends ConsumerState<FinancialDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financialDashboardViewModelProvider);
    final transactionsAsync = ref.watch(financialTransactionsProvider);
    final viewModel = ref.read(financialDashboardViewModelProvider.notifier);
    final currentUser = ref.watch(appUserProvider).value;
    final theme = Theme.of(context);

    if (!state.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: AppBarTitle(
            text: context.t('finance.title'),
          ),
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: carouselBoxDecoration(context),
            child: Text(
              context.t(
                  'ui.financial_dashboard.financial_dashboard_is_available_only_for_members_of_th'),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t('finance.title'),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => viewModel.refresh(),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  sliver: SliverToBoxAdapter(
                    child: _FinancialHeroCard(
                      churchName: state.churchName,
                      isRefreshing: transactionsAsync.isRefreshing,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 860;
                        return GridView.count(
                          crossAxisCount: wide ? 4 : 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: wide ? 1.35 : 0.86,
                          children: [
                            _FinanceSummaryCard(
                              title: context
                                  .t('ui.financial_dashboard.total_income'),
                              value: _currency(state.totalIncome),
                              subtitle: context.t(
                                'finance.income_record_count',
                                parameters: {
                                  'count':
                                      '${state.financialYearTransactions.where((item) => item.type == ChurchTransactionType.income).length}',
                                },
                              ),
                              icon: Icons.arrow_downward_rounded,
                              accent: const Color(0xFF28A26A),
                            ),
                            _FinanceSummaryCard(
                              title: context
                                  .t('ui.financial_dashboard.total_expenses'),
                              value: _currency(state.totalExpense),
                              subtitle: context.t(
                                'finance.expense_record_count',
                                parameters: {
                                  'count':
                                      '${state.financialYearTransactions.where((item) => item.type == ChurchTransactionType.expense).length}',
                                },
                              ),
                              icon: Icons.arrow_upward_rounded,
                              accent: const Color(0xFFD66C4A),
                            ),
                            _FinanceSummaryCard(
                              title: context
                                  .t('ui.financial_dashboard.bank_balance'),
                              value: _currency(state.bankBalance),
                              subtitle: context.t(
                                state.setup.banks.length == 1
                                    ? 'finance.bank_configured_singular'
                                    : 'finance.bank_configured_plural',
                                parameters: {
                                  'count': '${state.setup.banks.length}'
                                },
                              ),
                              icon: Icons.account_balance_outlined,
                              accent: const Color(0xFF5878F0),
                            ),
                            _FinanceSummaryCard(
                              title: context
                                  .t('ui.financial_dashboard.cash_in_hand'),
                              value: _currency(state.cashInHand),
                              subtitle: state.setup.config.currentFinancialYear,
                              icon: Icons.payments_outlined,
                              accent: const Color(0xFF8C5AF7),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _FinanceSetupCard(
                      setup: state.setup,
                      onEditConfig: () => _showConfigSheet(context),
                      onAddBank: () => _showBankSheet(context),
                      onAddLedger: () => _showLedgerSheet(context),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _DashboardSectionCard(
                      title:
                          context.t('ui.financial_dashboard.ledger_dashboards'),
                      subtitle: context.t(
                          'ui.financial_dashboard.track_how_each_finance_bucket_is_performing_across_r'),
                      child: state.categorySummaries.isEmpty
                          ? _FinanceEmptyState(
                              title: context.t(
                                  'ui.financial_dashboard.no_ledger_data_yet'),
                              subtitle: context.t(
                                  'ui.financial_dashboard.recorded_transactions_will_automatically_build_ledge'),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 980
                                    ? 3
                                    : constraints.maxWidth >= 640
                                        ? 2
                                        : 1;
                                return GridView.builder(
                                  itemCount: state.categorySummaries.length,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 2.1,
                                  ),
                                  itemBuilder: (context, index) {
                                    final summary =
                                        state.categorySummaries[index];
                                    return _LedgerDashboardTile(
                                        summary: summary);
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _DashboardSectionCard(
                      title: context.t('ui.financial_dashboard.monthly_trends'),
                      subtitle: context.t(
                          'ui.financial_dashboard.income_and_expense_flow_across_the_last_six_months_t'),
                      child: _MonthlyTrendChart(
                        summaries: state.monthlySummaries,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _DashboardSectionCard(
                      title: context.t('ui.financial_dashboard.day_book'),
                      subtitle: context.t(
                          'ui.financial_dashboard.daily_income_and_expense_movement_for_the_selected_f'),
                      child: _DayBookSection(
                        state: state,
                        onPickRange: () => _pickDayBookRange(context),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _AccountingReportsSection(state: state),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _DashboardSectionCard(
                      title: context
                          .t('ui.financial_dashboard.manage_transactions'),
                      subtitle: context.t(
                          'ui.financial_dashboard.search_filter_and_maintain_church_finance_records_in'),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  state.filteredTransactionCount ==
                                          state.pagedTransactions.length
                                      ? '${state.filteredTransactionCount} transaction${state.filteredTransactionCount == 1 ? '' : 's'} showing'
                                      : 'Showing ${state.pagedTransactions.length} of ${state.filteredTransactionCount} transactions',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.72),
                                  ),
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: state.isSubmitting
                                    ? null
                                    : () => _showAddTransactionSheet(
                                          context,
                                          currentUserName:
                                              currentUser?.name ?? '',
                                        ),
                                icon: const Icon(Icons.add_rounded),
                                label: Text(context.t(
                                    'ui.financial_dashboard.add_transaction')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            variant: AppTextFieldVariant.search,
                            controller: _searchController,
                            onChanged: viewModel.setQuery,
                            decoration: InputDecoration(
                              hintText: context.t(
                                  'ui.financial_dashboard.search_by_title_ledger_party_payment_method_referenc'),
                              prefixIcon: Padding(
                                padding:
                                    const EdgeInsets.only(left: 10, right: 6),
                                child: Icon(
                                  Icons.search_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              suffixIcon: state.query.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        viewModel.clearQuery();
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 860;
                              if (!wide) {
                                return Column(
                                  children: [
                                    AppDropdownField<String>(
                                      labelText: context
                                          .t('ui.financial_dashboard.type'),
                                      initialValue: state.selectedType,
                                      items: state.types
                                          .map(
                                            (value) => DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        viewModel.selectType(value);
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    AppDropdownField<String>(
                                      labelText: context
                                          .t('ui.financial_dashboard.status'),
                                      initialValue: state.selectedStatus,
                                      items: state.statuses
                                          .map(
                                            (value) => DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        viewModel.selectStatus(value);
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    AppDropdownField<String>(
                                      labelText: context
                                          .t('ui.financial_dashboard.ledger'),
                                      initialValue: state.selectedCategory,
                                      items: state.categories
                                          .map(
                                            (value) => DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        viewModel.selectCategory(value);
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    AppDropdownField<TransactionSortOption>(
                                      labelText: context
                                          .t('ui.financial_dashboard.sort_by'),
                                      initialValue: state.sortOption,
                                      items: TransactionSortOption.values
                                          .map(
                                            (value) => DropdownMenuItem<
                                                TransactionSortOption>(
                                              value: value,
                                              child: Text(
                                                context.t(_sortTextKey(value)),
                                              ),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        viewModel.selectSortOption(value);
                                      },
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(
                                    child: AppDropdownField<String>(
                                      labelText: context.t(
                                          'ui.financial_dashboard.type_3deb'),
                                      initialValue: state.selectedType,
                                      items: state.types
                                          .map(
                                            (value) => DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        viewModel.selectType(value);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AppDropdownField<String>(
                                      labelText: context.t(
                                          'ui.financial_dashboard.status_bae7'),
                                      initialValue: state.selectedStatus,
                                      items: state.statuses
                                          .map(
                                            (value) => DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        viewModel.selectStatus(value);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AppDropdownField<String>(
                                      labelText: context
                                          .t('ui.financial_dashboard.ledger'),
                                      initialValue: state.selectedCategory,
                                      items: state.categories
                                          .map(
                                            (value) => DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        viewModel.selectCategory(value);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child:
                                        AppDropdownField<TransactionSortOption>(
                                      labelText: context.t(
                                          'ui.financial_dashboard.sort_by_a2a5'),
                                      initialValue: state.sortOption,
                                      items: TransactionSortOption.values
                                          .map(
                                            (value) => DropdownMenuItem<
                                                TransactionSortOption>(
                                              value: value,
                                              child: Text(
                                                context.t(_sortTextKey(value)),
                                              ),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        viewModel.selectSortOption(value);
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          if (state.activeFilterCount > 0) ...[
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  context.t(
                                    state.activeFilterCount == 1
                                        ? 'finance.active_filter_singular'
                                        : 'finance.active_filter_plural',
                                    parameters: {
                                      'count': '${state.activeFilterCount}',
                                    },
                                  ),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (transactionsAsync.isLoading && state.transactions.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: AppLoadingIndicator()),
                  )
                else if (transactionsAsync.hasError &&
                    state.transactions.isEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
                    sliver: SliverToBoxAdapter(
                      child: _FinanceEmptyState(
                        title: context.t(
                            'ui.financial_dashboard.unable_to_load_transactions'),
                        subtitle: context.t(
                            'ui.financial_dashboard.check_your_connection_or_try_again_in_a_moment'),
                      ),
                    ),
                  )
                else if (state.filteredTransactionCount == 0)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
                    sliver: SliverToBoxAdapter(
                      child: _FinanceEmptyState(
                        title: context.t(
                            'ui.financial_dashboard.no_matching_transactions'),
                        subtitle: context.t(
                            'ui.financial_dashboard.adjust_the_filters_or_add_a_new_transaction_to_get_s'),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _TransactionListPerformanceHint(
                            totalTransactions: state.totalCount,
                            filteredTransactionCount:
                                state.filteredTransactionCount,
                          ),
                        ),
                        SliverList.builder(
                          itemCount: state.pagedTransactions.length,
                          itemBuilder: (context, index) {
                            final item = state.pagedTransactions[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    index == state.pagedTransactions.length - 1
                                        ? 0
                                        : 12,
                              ),
                              child: _TransactionListCard(
                                item: item,
                                onTap: () =>
                                    _showTransactionDetails(context, item),
                              ),
                            );
                          },
                        ),
                        if (state.hasMoreVisibleTransactions)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Center(
                                child: FilledButton.tonalIcon(
                                  onPressed: state.isSubmitting ||
                                          state.isLoadingMoreTransactions
                                      ? null
                                      : () {
                                          ref
                                              .read(
                                                financialDashboardViewModelProvider
                                                    .notifier,
                                              )
                                              .showMoreTransactions();
                                        },
                                  icon: state.isLoadingMoreTransactions
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.expand_more_rounded),
                                  label: Text(
                                    state.isLoadingMoreTransactions
                                        ? 'Loading records'
                                        : 'Load ${FinancialDashboardViewState.defaultVisibleTransactionCount} more',
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (state.isSubmitting)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: theme.colorScheme.scrim.withValues(alpha: 0.22),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 22,
                      ),
                      decoration: carouselBoxDecoration(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.6),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            context
                                .t('ui.financial_dashboard.saving_transaction'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddTransactionSheet(
    BuildContext context, {
    required String currentUserName,
  }) async {
    final type = await showAppModalBottomSheet<ChurchTransactionType>(
      context: context,
      isScrollControlled: true,
      heightFactor: 0.5,
      builder: (_) => const _TransactionTypePickerSheet(),
    );
    if (type == null || !context.mounted) return;

    final state = ref.read(financialDashboardViewModelProvider);
    final form = await showAppModalBottomSheet<ChurchTransactionFormData>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransactionFormSheet(
        initialType: type,
        initialRecordedBy: currentUserName,
        setup: state.setup,
        ledgers: state.ledgers,
        onPickPartyName: _pickPartyName,
      ),
    );

    if (form == null || !context.mounted) return;
    try {
      await ref
          .read(financialDashboardViewModelProvider.notifier)
          .addTransaction(form);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'finance.save_transaction_failed',
              parameters: {'error': '$error'},
            ),
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('finance.transaction_added',
              parameters: {'title': form.title}),
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, ChurchTransaction item) {
    showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.84,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TypePill(type: item.type),
                      _StatusPill(status: item.status),
                      _MetaPill(label: item.ledgerName),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DetailRow(
                      label: context.t('ui.financial_dashboard.amount'),
                      value: _currency(item.amount)),
                  _DetailRow(
                      label: context.t('ui.financial_dashboard.date'),
                      value: _date(item.transactionDate)),
                  _DetailRow(
                    label: context.t('ui.financial_dashboard.voucher'),
                    value: item.voucherNumber.trim().isEmpty
                        ? item.voucherType.label
                        : '${item.voucherType.label} • ${item.voucherNumber}',
                  ),
                  _DetailRow(
                    label: context.t('ui.financial_dashboard.debit'),
                    value: item.debitLedgerName.trim().isEmpty
                        ? (item.type == ChurchTransactionType.income
                            ? item.paymentMethod
                            : item.ledgerName)
                        : item.debitLedgerName,
                  ),
                  _DetailRow(
                    label: context.t('ui.financial_dashboard.credit'),
                    value: item.creditLedgerName.trim().isEmpty
                        ? (item.type == ChurchTransactionType.income
                            ? item.ledgerName
                            : item.paymentMethod)
                        : item.creditLedgerName,
                  ),
                  _DetailRow(
                    label: context.t('ui.financial_dashboard.party_name'),
                    value: item.partyName.trim().isEmpty
                        ? 'Not provided'
                        : item.partyName,
                  ),
                  _DetailRow(
                      label: context.t('ui.financial_dashboard.ledger'),
                      value: item.ledgerName),
                  _DetailRow(
                    label: context.t('ui.financial_dashboard.ledger_group'),
                    value: item.ledgerGroup.trim().isEmpty
                        ? 'Not provided'
                        : item.ledgerGroup,
                  ),
                  _DetailRow(
                      label: context.t('ui.financial_dashboard.payment_method'),
                      value: item.paymentMethod),
                  _DetailRow(
                    label: context.t('ui.financial_dashboard.reference'),
                    value: item.reference.trim().isEmpty
                        ? 'Not provided'
                        : item.reference,
                  ),
                  _DetailRow(
                    label: context.t('ui.financial_dashboard.recorded_by'),
                    value: item.recordedBy.trim().isEmpty
                        ? 'Not provided'
                        : item.recordedBy,
                  ),
                  _DetailRow(
                    label: context.t('ui.financial_dashboard.description'),
                    value: item.description.trim().isEmpty
                        ? 'No notes added'
                        : item.description,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _showEditTransactionSheet(context, item);
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(context.t('ui.financial_dashboard.edit')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _deleteTransaction(context, item);
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: Text(
                              context.t('ui.financial_dashboard.delete_79b1')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditTransactionSheet(
    BuildContext context,
    ChurchTransaction item,
  ) async {
    final state = ref.read(financialDashboardViewModelProvider);
    final form = await showAppModalBottomSheet<ChurchTransactionFormData>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransactionFormSheet(
        existingItem: item,
        initialType: item.type,
        initialRecordedBy: item.recordedBy,
        setup: state.setup,
        ledgers: state.ledgers,
        onPickPartyName: _pickPartyName,
      ),
    );

    if (form == null || !context.mounted) return;
    try {
      await ref
          .read(financialDashboardViewModelProvider.notifier)
          .updateTransaction(form);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'finance.update_transaction_failed',
              parameters: {'error': '$error'},
            ),
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('finance.transaction_updated',
              parameters: {'title': form.title}),
        ),
      ),
    );
  }

  Future<void> _showConfigSheet(BuildContext context) async {
    final state = ref.read(financialDashboardViewModelProvider);
    final config = await showAppModalBottomSheet<FinanceConfig>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FinanceConfigSheet(config: state.setup.config),
    );
    if (config == null || !context.mounted) return;
    try {
      await ref
          .read(financialDashboardViewModelProvider.notifier)
          .saveConfig(config);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('finance.save_settings_failed',
                parameters: {'error': '$error'}),
          ),
        ),
      );
    }
  }

  Future<void> _showBankSheet(BuildContext context) async {
    final bank = await showAppModalBottomSheet<FinanceBankAccount>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BankAccountSheet(),
    );
    if (bank == null || !context.mounted) return;
    try {
      await ref
          .read(financialDashboardViewModelProvider.notifier)
          .upsertBank(bank);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .t('finance.save_bank_failed', parameters: {'error': '$error'}),
          ),
        ),
      );
    }
  }

  Future<void> _showLedgerSheet(BuildContext context) async {
    final ledger = await showAppModalBottomSheet<FinanceLedger>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LedgerSheet(),
    );
    if (ledger == null || !context.mounted) return;
    try {
      await ref
          .read(financialDashboardViewModelProvider.notifier)
          .upsertLedger(ledger);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('finance.save_ledger_failed',
                parameters: {'error': '$error'}),
          ),
        ),
      );
    }
  }

  Future<void> _pickDayBookRange(BuildContext context) async {
    final state = ref.read(financialDashboardViewModelProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: state.dayBookStartDate,
        end: state.dayBookEndDate,
      ),
    );
    if (picked == null) return;
    ref.read(financialDashboardViewModelProvider.notifier).setDayBookRange(
          picked.start,
          picked.end,
        );
  }

  Future<String?> _pickPartyName(BuildContext context) async {
    final churchId = await ref.read(currentChurchIdProvider.future);
    if (churchId == null || churchId.trim().isEmpty || !context.mounted) {
      return null;
    }
    return showAppModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MemberPartyPickerSheet(
        repository: MembersRepository(
          firestore: FirebaseFirestore.instance,
          churchId: churchId,
        ),
      ),
    );
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    ChurchTransaction item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('ui.financial_dashboard.delete_transaction')),
        content: Text(
          context.t(
            'finance.delete_transaction_message',
            parameters: {'title': item.title},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.t('ui.financial_dashboard.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.t('ui.financial_dashboard.delete_79b1')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(financialDashboardViewModelProvider.notifier)
          .deleteTransaction(item);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('finance.delete_transaction_failed',
                parameters: {'error': '$error'}),
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('finance.transaction_deleted',
              parameters: {'title': item.title}),
        ),
      ),
    );
  }
}

class _FinancialHeroCard extends StatelessWidget {
  const _FinancialHeroCard({
    required this.churchName,
    required this.isRefreshing,
  });

  final String churchName;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    return Container(
      decoration: welcomeBackCardDecoration(context),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroChip(
                icon: Icons.groups_2_outlined,
                label: context.t('ui.financial_dashboard.finance_team'),
                color: onPrimary,
              ),
              _HeroChip(
                icon: Icons.sync_rounded,
                label: isRefreshing ? 'Refreshing...' : 'Live records',
                color: onPrimary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            churchName.trim().isEmpty
                ? 'Church Finance'
                : '$churchName Finance',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: onPrimary,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.t(
                'ui.financial_dashboard.track_offerings_expenses_project_spend_and_overall_cash'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: onPrimary.withValues(alpha: 0.88),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceSetupCard extends StatelessWidget {
  const _FinanceSetupCard({
    required this.setup,
    required this.onEditConfig,
    required this.onAddBank,
    required this.onAddLedger,
  });

  final FinanceSetup setup;
  final VoidCallback onEditConfig;
  final VoidCallback onAddBank;
  final VoidCallback onAddLedger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = setup.config;
    return _DashboardSectionCard(
      title: context.t('ui.financial_dashboard.config_settings'),
      subtitle: context.t(
          'ui.financial_dashboard.trust_details_financial_year_bank_accounts_and_custo'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetaPill(
                label: config.trustName.trim().isEmpty
                    ? context.t('finance.trust_name_not_set')
                    : config.trustName,
              ),
              _MetaPill(
                label: context.t(
                  'finance.financial_year_short',
                  parameters: {'year': config.currentFinancialYear},
                ),
              ),
              _MetaPill(
                label: context.t(
                  'finance.bank_account_count',
                  parameters: {'count': '${setup.banks.length}'},
                ),
              ),
              _MetaPill(
                label: context.t(
                  'finance.ledger_count',
                  parameters: {'count': '${setup.ledgers.length}'},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: onEditConfig,
                icon: const Icon(Icons.tune_rounded),
                label: Text(context.t('ui.financial_dashboard.edit_config')),
              ),
              OutlinedButton.icon(
                onPressed: onAddBank,
                icon: const Icon(Icons.account_balance_outlined),
                label: Text(context.t('ui.financial_dashboard.add_bank')),
              ),
              OutlinedButton.icon(
                onPressed: onAddLedger,
                icon: const Icon(Icons.book_outlined),
                label: Text(context.t('ui.financial_dashboard.add_ledger')),
              ),
            ],
          ),
          if (setup.banks.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.t('ui.financial_dashboard.bank_accounts'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ...setup.banks.take(3).map(
                  (bank) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DetailRow(
                      label: bank.accountName,
                      value: bank.branchDetails.trim().isEmpty
                          ? bank.accountNumber
                          : '${bank.accountNumber} • ${bank.branchDetails}',
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _DayBookSection extends StatelessWidget {
  const _DayBookSection({
    required this.state,
    required this.onPickRange,
  });

  final FinancialDashboardViewState state;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _TrendMetricPill(
              label: context.t('ui.financial_dashboard.income'),
              value: _currency(state.dayBookIncome),
              color: const Color(0xFF28A26A),
            ),
            _TrendMetricPill(
              label: context.t('ui.financial_dashboard.expense'),
              value: _currency(state.dayBookExpense),
              color: const Color(0xFFD66C4A),
            ),
            _TrendMetricPill(
              label: context.t('ui.financial_dashboard.closing'),
              value: _currency(state.dayBookClosingBalance),
              color: theme.colorScheme.primary,
            ),
            OutlinedButton.icon(
              onPressed: onPickRange,
              icon: const Icon(Icons.date_range_outlined),
              label: Text('${_shortDate(state.dayBookStartDate)} - '
                  '${_shortDate(state.dayBookEndDate)}'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (state.dayBookTransactions.isEmpty)
          _FinanceEmptyState(
            title: context.t('ui.financial_dashboard.no_day_book_entries'),
            subtitle: context.t(
                'ui.financial_dashboard.pick_another_date_range_or_add_a_transaction'),
          )
        else
          ...state.dayBookTransactions.take(12).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DayBookRow(item: item),
                ),
              ),
      ],
    );
  }
}

class _DayBookRow extends StatelessWidget {
  const _DayBookRow({required this.item});

  final ChurchTransaction item;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(item.type);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_shortDate(item.transactionDate)} • ${item.type.label}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.ledgerName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.partyName.trim().isEmpty ? context.t('finance.no_party') : item.partyName} • ${item.paymentMethod}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _currency(item.amount),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _AccountingReportsSection extends StatelessWidget {
  const _AccountingReportsSection({required this.state});

  final FinancialDashboardViewState state;

  @override
  Widget build(BuildContext context) {
    return _DashboardSectionCard(
      title: context.t('ui.financial_dashboard.accounting_reports'),
      subtitle: context.t(
          'ui.financial_dashboard.tally_style_essentials_generated_from_every_debit_an'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TrendMetricPill(
                label: context.t('ui.financial_dashboard.trial_dr'),
                value: _currency(state.trialDebitTotal),
                color: const Color(0xFF28A26A),
              ),
              _TrendMetricPill(
                label: context.t('ui.financial_dashboard.trial_cr'),
                value: _currency(state.trialCreditTotal),
                color: const Color(0xFFD66C4A),
              ),
              _TrendMetricPill(
                label: context.t('ui.financial_dashboard.difference'),
                value: _currency(
                  (state.trialDebitTotal - state.trialCreditTotal).abs(),
                ),
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MiniReportCard(
            title: context.t('ui.financial_dashboard.trial_balance'),
            subtitle: context.t(
                'ui.financial_dashboard.every_ledger_should_balance_debit_and_credit_totals'),
            emptyTitle:
                context.t('ui.financial_dashboard.no_trial_balance_yet'),
            emptySubtitle: context.t(
                'ui.financial_dashboard.record_transactions_to_generate_trial_balance'),
            child: Column(
              children: state.trialBalanceRows
                  .take(8)
                  .map((row) => _TrialBalanceTile(row: row))
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 14),
          _MiniReportCard(
            title: context.t('ui.financial_dashboard.cash_book'),
            subtitle: context.t(
                'ui.financial_dashboard.cash_in_hand_movement_from_receipts_and_payments'),
            emptyTitle: context.t('ui.financial_dashboard.no_cash_entries_yet'),
            emptySubtitle: context
                .t('ui.financial_dashboard.cash_transactions_will_appear_here'),
            child: Column(
              children: state.cashBookRows
                  .take(6)
                  .map((row) => _LedgerStatementTile(row: row))
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 14),
          _MiniReportCard(
            title: context.t('ui.financial_dashboard.bank_book'),
            subtitle: context.t(
                'ui.financial_dashboard.bank_account_movement_across_configured_accounts'),
            emptyTitle: context.t('finance.no_bank_entries'),
            emptySubtitle: context.t('finance.bank_entries_description'),
            child: Column(
              children: state.bankBookRows
                  .take(6)
                  .map((row) => _LedgerStatementTile(row: row))
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniReportCard extends StatelessWidget {
  const _MiniReportCard({
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptySubtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = child is Column && (child as Column).children.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: carouselBoxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 12),
          if (isEmpty)
            _FinanceEmptyState(title: emptyTitle, subtitle: emptySubtitle)
          else
            child,
        ],
      ),
    );
  }
}

class _TrialBalanceTile extends StatelessWidget {
  const _TrialBalanceTile({required this.row});

  final TrialBalanceRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.ledgerName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  row.ledgerGroup,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          Text(
            context.t(
              'finance.debit_short_value',
              parameters: {'value': _currency(row.debit)},
            ),
            style: theme.textTheme.labelLarge?.copyWith(
              color: const Color(0xFF28A26A),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            context.t(
              'finance.credit_short_value',
              parameters: {'value': _currency(row.credit)},
            ),
            style: theme.textTheme.labelLarge?.copyWith(
              color: const Color(0xFFD66C4A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerStatementTile extends StatelessWidget {
  const _LedgerStatementTile({required this.row});

  final LedgerStatementRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_shortDate(row.transaction.transactionDate)} • '
                  '${row.transaction.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  context.t(
                    'finance.ledger_balance',
                    parameters: {
                      'ledger': row.ledgerName,
                      'balance': _currency(row.runningBalance),
                    },
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          Text(
            row.debit > 0
                ? 'Dr ${_currency(row.debit)}'
                : 'Cr ${_currency(row.credit)}',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: row.debit > 0
                  ? const Color(0xFF28A26A)
                  : const Color(0xFFD66C4A),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _FinanceSummaryCard extends StatelessWidget {
  const _FinanceSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: carouselBoxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DashboardSectionCard extends StatelessWidget {
  const _DashboardSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: carouselBoxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: onSurface.withValues(alpha: 0.78),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _LedgerDashboardTile extends StatelessWidget {
  const _LedgerDashboardTile({required this.summary});

  final FinancialCategorySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = summary.isExpenseHeavy
        ? const Color(0xFFD66C4A)
        : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: carouselBoxDecoration(context),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(summary.icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  summary.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t(
                    summary.transactionCount == 1
                        ? 'finance.transaction_count_singular'
                        : 'finance.transaction_count_plural',
                    parameters: {'count': '${summary.transactionCount}'},
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _currency(summary.balance),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyTrendChart extends StatefulWidget {
  const _MonthlyTrendChart({required this.summaries});

  final List<MonthlyFinanceSummary> summaries;

  @override
  State<_MonthlyTrendChart> createState() => _MonthlyTrendChartState();
}

class _MonthlyTrendChartState extends State<_MonthlyTrendChart> {
  int _selectedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final summaries = widget.summaries;

    if (summaries.every((item) => item.total <= 0)) {
      return _FinanceEmptyState(
        title: context.t('ui.financial_dashboard.no_trend_data_yet'),
        subtitle: context.t(
            'ui.financial_dashboard.monthly_charts_will_appear_as_transactions_are_recor'),
      );
    }

    final maxValue = summaries
        .map((item) => item.total)
        .fold<double>(0, (max, value) => value > max ? value : max);

    final selectedSummary =
        _selectedIndex >= 0 && _selectedIndex < summaries.length
            ? summaries[_selectedIndex]
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(
                label: context.t('ui.financial_dashboard.income_1c89'),
                color: Color(0xFF28A26A)),
            SizedBox(width: 16),
            _LegendDot(
                label: context.t('ui.financial_dashboard.expenses'),
                color: Color(0xFFD66C4A)),
          ],
        ),
        if (selectedSummary != null) ...[
          const SizedBox(height: 16),
          _MonthlyTrendDetail(summary: selectedSummary),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 220,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / summaries.length;
              final horizontalPadding = slotWidth < 56 ? 2.0 : 4.0;
              final containerPadding = slotWidth < 56 ? 2.0 : 4.0;
              final barGap = slotWidth < 56 ? 4.0 : 8.0;
              final barWidth = ((slotWidth -
                          (horizontalPadding * 2) -
                          (containerPadding * 2) -
                          barGap) /
                      2)
                  .clamp(8.0, 16.0);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: summaries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final summary = entry.value;
                  final isSelected = index == _selectedIndex;
                  return Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          setState(() {
                            _selectedIndex = isSelected ? -1 : index;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          padding: EdgeInsets.symmetric(
                            horizontal: containerPadding,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _TrendBar(
                                        value: summary.income,
                                        maxValue: maxValue,
                                        color: const Color(0xFF28A26A),
                                        isSelected: isSelected,
                                        width: barWidth,
                                      ),
                                      SizedBox(width: barGap),
                                      _TrendBar(
                                        value: summary.expense,
                                        maxValue: maxValue,
                                        color: const Color(0xFFD66C4A),
                                        isSelected: isSelected,
                                        width: barWidth,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                DateFormat('MMM').format(summary.month),
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      fontSize: slotWidth < 56 ? 11 : null,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.value,
    required this.maxValue,
    required this.color,
    required this.isSelected,
    required this.width,
  });

  final double value;
  final double maxValue;
  final Color color;
  final bool isSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    final normalized = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: width,
      height: 150 * normalized + 6,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isSelected ? 1 : 0.88),
        borderRadius: BorderRadius.circular(999),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
    );
  }
}

class _MonthlyTrendDetail extends StatelessWidget {
  const _MonthlyTrendDetail({required this.summary});

  final MonthlyFinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(summary.month),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _TrendMetricPill(
                label: context.t('ui.financial_dashboard.income_1c89'),
                value: _currency(summary.income),
                color: const Color(0xFF28A26A),
              ),
              _TrendMetricPill(
                label: context.t('ui.financial_dashboard.expenses_8d43'),
                value: _currency(summary.expense),
                color: const Color(0xFFD66C4A),
              ),
              _TrendMetricPill(
                label: context.t('ui.financial_dashboard.net'),
                value: _currency(summary.income - summary.expense),
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendMetricPill extends StatelessWidget {
  const _TrendMetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebitCreditPreview extends StatelessWidget {
  const _DebitCreditPreview({
    required this.debitLedger,
    required this.creditLedger,
    required this.voucherType,
  });

  final String debitLedger;
  final String creditLedger;
  final ChurchVoucherType voucherType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(
              'finance.voucher_type',
              parameters: {'type': voucherType.label},
            ),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'finance.debit_ledger',
              parameters: {'ledger': debitLedger},
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.t(
              'finance.credit_ledger',
              parameters: {'ledger': creditLedger},
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
                'ui.financial_dashboard.we_post_this_automatically_no_accounting_knowledge_need'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionListPerformanceHint extends StatelessWidget {
  const _TransactionListPerformanceHint({
    required this.totalTransactions,
    required this.filteredTransactionCount,
  });

  final int totalTransactions;
  final int filteredTransactionCount;

  @override
  Widget build(BuildContext context) {
    if (totalTransactions < 40) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.tune_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              filteredTransactionCount == totalTransactions
                  ? 'Large finance history detected. Transactions are shown in smaller batches to keep scrolling smooth.'
                  : 'Filters are helping narrow a large finance history. Load more only when you need deeper results.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.76),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 10,
          width: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _TransactionListCard extends StatelessWidget {
  const _TransactionListCard({
    required this.item,
    required this.onTap,
  });

  final ChurchTransaction item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(item.type);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(cornerRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: carouselBoxDecoration(context),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.type == ChurchTransactionType.income
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: typeColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description.trim().isEmpty
                          ? '${item.ledgerName} • ${item.paymentMethod}'
                          : item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.72),
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TypePill(type: item.type),
                        _StatusPill(status: item.status),
                        _MetaPill(label: _date(item.transactionDate)),
                        _MetaPill(label: item.ledgerName),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currency(item.amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: typeColor,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});

  final ChurchTransactionType type;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return _PillLabel(
      label: type.label,
      foreground: color,
      background: color.withValues(alpha: 0.12),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ChurchTransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == ChurchTransactionStatus.pending
        ? const Color(0xFF8C5AF7)
        : const Color(0xFF28A26A);
    return _PillLabel(
      label: status.label,
      foreground: color,
      background: color.withValues(alpha: 0.12),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PillLabel(
      label: label,
      foreground: theme.colorScheme.onSurface.withValues(alpha: 0.72),
      background: theme.colorScheme.onSurface.withValues(alpha: 0.07),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.72),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _FinanceEmptyState extends StatelessWidget {
  const _FinanceEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: carouselBoxDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TransactionTypePickerSheet extends StatelessWidget {
  const _TransactionTypePickerSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t('ui.financial_dashboard.what_are_we_recording'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.t(
                  'ui.financial_dashboard.use_plain_choices_we_will_create_the_debit_and_credit_e'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 18),
            _TransactionTypeOption(
              icon: Icons.arrow_downward_rounded,
              title: context.t('ui.financial_dashboard.money_received'),
              subtitle: context.t(
                  'ui.financial_dashboard.receipt_voucher_cash_bank_dr_income_ledger_cr'),
              color: const Color(0xFF28A26A),
              onTap: () => Navigator.of(context).pop(
                ChurchTransactionType.income,
              ),
            ),
            const SizedBox(height: 12),
            _TransactionTypeOption(
              icon: Icons.arrow_upward_rounded,
              title: context.t('ui.financial_dashboard.money_paid'),
              subtitle: context.t(
                  'ui.financial_dashboard.payment_voucher_expense_ledger_dr_cash_bank_cr'),
              color: const Color(0xFFD66C4A),
              onTap: () => Navigator.of(context).pop(
                ChurchTransactionType.expense,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTypeOption extends StatelessWidget {
  const _TransactionTypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: carouselBoxDecoration(context),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceConfigSheet extends StatefulWidget {
  const _FinanceConfigSheet({required this.config});

  final FinanceConfig config;

  @override
  State<_FinanceConfigSheet> createState() => _FinanceConfigSheetState();
}

class _FinanceConfigSheetState extends State<_FinanceConfigSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _trustNameController;
  late final TextEditingController _registrationController;
  late final TextEditingController _panController;
  late final TextEditingController _mainAccountController;
  late final TextEditingController _branchController;
  late final TextEditingController _yearController;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    _trustNameController = TextEditingController(text: config.trustName);
    _registrationController =
        TextEditingController(text: config.registrationNumber);
    _panController = TextEditingController(text: config.panNumber);
    _mainAccountController =
        TextEditingController(text: config.mainBankAccountNumber);
    _branchController = TextEditingController(text: config.bankBranchDetails);
    _yearController = TextEditingController(text: config.currentFinancialYear);
  }

  @override
  void dispose() {
    _trustNameController.dispose();
    _registrationController.dispose();
    _panController.dispose();
    _mainAccountController.dispose();
    _branchController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(
                  controller: _trustNameController,
                  label: context.t('ui.financial_dashboard.trust_account_name'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _registrationController,
                  label: context
                      .t('ui.financial_dashboard.trust_registration_number'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _panController,
                  label: context.t('ui.financial_dashboard.trust_pan_number'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _mainAccountController,
                  label: context
                      .t('ui.financial_dashboard.main_bank_account_number'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _branchController,
                  label:
                      context.t('ui.financial_dashboard.bank_branch_details'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _yearController,
                  label: context
                      .t('ui.financial_dashboard.current_financial_year'),
                  hintText: '2025-2026',
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child:
                        Text(context.t('ui.financial_dashboard.save_config')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(
      FinanceConfig(
        trustName: _trustNameController.text.trim(),
        registrationNumber: _registrationController.text.trim(),
        panNumber: _panController.text.trim(),
        mainBankAccountNumber: _mainAccountController.text.trim(),
        bankBranchDetails: _branchController.text.trim(),
        currentFinancialYear: _yearController.text.trim(),
      ),
    );
  }
}

class _BankAccountSheet extends StatefulWidget {
  const _BankAccountSheet();

  @override
  State<_BankAccountSheet> createState() => _BankAccountSheetState();
}

class _BankAccountSheetState extends State<_BankAccountSheet> {
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _branchController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: _nameController,
              label: context.t('ui.financial_dashboard.bank_account_name'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _numberController,
              label: context.t('ui.financial_dashboard.account_number'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _branchController,
              label: context.t('ui.financial_dashboard.branch_details'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(context.t('ui.financial_dashboard.save_bank')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      FinanceBankAccount(
        id: _slug(name),
        accountName: name,
        accountNumber: _numberController.text.trim(),
        branchDetails: _branchController.text.trim(),
        isPrimary: false,
      ),
    );
  }
}

class _LedgerSheet extends StatefulWidget {
  const _LedgerSheet();

  @override
  State<_LedgerSheet> createState() => _LedgerSheetState();
}

class _LedgerSheetState extends State<_LedgerSheet> {
  final _nameController = TextEditingController();
  String _selectedGroup = financeLedgerGroups.first;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: _nameController,
              label: context.t('ui.financial_dashboard.ledger_name'),
            ),
            const SizedBox(height: 12),
            AppDropdownField<String>(
              labelText: context.t('ui.financial_dashboard.ledger_group'),
              initialValue: _selectedGroup,
              items: financeLedgerGroups
                  .map(
                    (group) => DropdownMenuItem<String>(
                      value: group,
                      child: Text(group),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedGroup = value);
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(context.t('ui.financial_dashboard.save_ledger')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      FinanceLedger(
        id: _slug(name),
        name: name,
        group: _selectedGroup,
      ),
    );
  }
}

class _MemberPartyPickerSheet extends StatefulWidget {
  const _MemberPartyPickerSheet({required this.repository});

  final MembersRepository repository;

  @override
  State<_MemberPartyPickerSheet> createState() =>
      _MemberPartyPickerSheetState();
}

class _MemberPartyPickerSheetState extends State<_MemberPartyPickerSheet> {
  final _queryController = TextEditingController();
  final List<AppUser> _members = <AppUser>[];
  DocumentSnapshot<AppUser>? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMembers(reset: true);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          children: [
            AppTextField(
              variant: AppTextFieldVariant.search,
              controller: _queryController,
              onChanged: (_) => _loadMembers(reset: true),
              decoration: InputDecoration(
                hintText: context.t('ui.financial_dashboard.search_members'),
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.primary.withValues(alpha: 0.06),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading && _members.isEmpty
                  ? const Center(child: AppLoadingIndicator())
                  : ListView.builder(
                      itemCount: _members.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _members.length) {
                          return Center(
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => _loadMembers(reset: false),
                              child: Text(_isLoading
                                  ? 'Loading...'
                                  : 'Load more members'),
                            ),
                          );
                        }
                        final member = _members[index];
                        return ListTile(
                          leading: AppProfileAvatar(
                            name: member.name,
                            imageUrl: member.profilePhotoUrl,
                          ),
                          title: Text(member.name),
                          subtitle: Text(member.email),
                          onTap: () => Navigator.of(context).pop(member.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMembers({required bool reset}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final page = await widget.repository.fetchMembersPage(
        query: _queryController.text,
        startAfter: reset ? null : _lastDocument,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _members.clear();
        _members.addAll(page.members);
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }
}

class _TransactionFormSheet extends StatefulWidget {
  const _TransactionFormSheet({
    this.existingItem,
    required this.initialType,
    required this.initialRecordedBy,
    required this.setup,
    required this.ledgers,
    required this.onPickPartyName,
  });

  final ChurchTransaction? existingItem;
  final ChurchTransactionType initialType;
  final String initialRecordedBy;
  final FinanceSetup setup;
  final List<FinanceLedger> ledgers;
  final Future<String?> Function(BuildContext context) onPickPartyName;

  @override
  State<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _partyNameController;
  late final TextEditingController _referenceController;
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  late final List<FinanceLedger> _ledgerOptions;
  late FinanceLedger _selectedLedger;
  late String _selectedPaymentMethod;
  late DateTime _selectedDate;
  late ChurchTransactionType _selectedType;
  late ChurchVoucherType _selectedVoucherType;
  late ChurchTransactionStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _titleController = TextEditingController(text: item?.title ?? '');
    _descriptionController =
        TextEditingController(text: item?.description ?? '');
    _partyNameController = TextEditingController(text: item?.partyName ?? '');
    _ledgerOptions = _buildLedgerOptions(widget.ledgers, item?.ledgerName);
    _selectedLedger = _ledgerOptions.firstWhere(
      (ledger) => ledger.name == (item?.ledgerName ?? ''),
      orElse: () => _ledgerOptions.first,
    );
    _selectedPaymentMethod =
        _normalizePaymentMethod(item?.paymentMethod ?? 'Cash', widget.setup);
    _referenceController = TextEditingController(text: item?.reference ?? '');
    _amountController = TextEditingController(
      text:
          item != null && item.amount > 0 ? item.amount.toStringAsFixed(2) : '',
    );
    _selectedDate = item?.transactionDate ?? DateTime.now();
    _dateController = TextEditingController(text: _date(_selectedDate));
    _selectedType = item?.type ?? widget.initialType;
    _selectedVoucherType = item?.voucherType ??
        (_selectedType == ChurchTransactionType.income
            ? ChurchVoucherType.receipt
            : ChurchVoucherType.payment);
    _selectedStatus = item?.status ?? ChurchTransactionStatus.cleared;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _partyNameController.dispose();
    _referenceController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _titleController,
                  label: _selectedVoucherType == ChurchVoucherType.receipt
                      ? 'Income title'
                      : 'Expense title',
                  hintText: _selectedType == ChurchTransactionType.income
                      ? 'Sunday service offering'
                      : 'Electricity bill',
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _partyNameController,
                        label: _selectedType == ChurchTransactionType.expense
                            ? 'Party Name *'
                            : 'Party Name',
                        hintText: context
                            .t('ui.financial_dashboard.member_or_vendor_name'),
                        suffixIcon: IconButton(
                          tooltip:
                              context.t('ui.financial_dashboard.select_member'),
                          onPressed: () async {
                            final name = await widget.onPickPartyName(context);
                            if (name == null || name.trim().isEmpty) return;
                            setState(() {
                              _partyNameController.text = name.trim();
                            });
                          },
                          icon: const Icon(Icons.person_search_outlined),
                        ),
                        validator: (value) {
                          if (_selectedType == ChurchTransactionType.expense &&
                              (value == null || value.trim().isEmpty)) {
                            return context.t('finance.party_name_required');
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDropdownField<ChurchTransactionStatus>(
                        labelText:
                            context.t('ui.financial_dashboard.status_bae7'),
                        initialValue: _selectedStatus,
                        items: ChurchTransactionStatus.values
                            .map(
                              (value) =>
                                  DropdownMenuItem<ChurchTransactionStatus>(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedStatus = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DebitCreditPreview(
                  debitLedger: _debitLedgerName(),
                  creditLedger: _creditLedgerName(),
                  voucherType: _selectedVoucherType,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppDropdownField<FinanceLedger>(
                        labelText: context.t('ui.financial_dashboard.ledger'),
                        initialValue: _selectedLedger,
                        items: _ledgerOptions
                            .map(
                              (value) => DropdownMenuItem<FinanceLedger>(
                                value: value,
                                child: Text('${value.name} • ${value.group}'),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedLedger = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDropdownField<String>(
                        labelText:
                            context.t('ui.financial_dashboard.payment_method'),
                        initialValue: _selectedPaymentMethod,
                        items: _paymentMethods(widget.setup)
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedPaymentMethod = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _amountController,
                        label: context.t('ui.financial_dashboard.amount_43dc'),
                        hintText: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        validator: (value) {
                          if (InputValidators.parsePositiveAmount(
                                value ?? '',
                              ) ==
                              null) {
                            return context.t('finance.amount_invalid');
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: context.t('ui.financial_dashboard.date_eb9a'),
                        controller: _dateController,
                        readOnly: true,
                        onTap: _pickDate,
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _referenceController,
                  label: context.t('ui.financial_dashboard.reference_db1c'),
                  hintText: context.t(
                      'ui.financial_dashboard.receipt_bank_reference_cheque_no'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _descriptionController,
                  label: context.t('ui.financial_dashboard.notes'),
                  hintText: context.t('ui.financial_dashboard.optional_notes'),
                  maxLines: 3,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(
                      widget.existingItem == null
                          ? 'Save Transaction'
                          : 'Update Transaction',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _dateController.text = _date(picked);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount =
        InputValidators.parsePositiveAmount(_amountController.text.trim());
    if (amount == null) return;
    Navigator.of(context).pop(
      ChurchTransactionFormData(
        id: widget.existingItem?.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedLedger.name.trim(),
        ledgerId: _selectedLedger.id.trim(),
        ledgerGroup: _selectedLedger.group.trim(),
        partyName: _partyNameController.text.trim(),
        paymentMethod: _selectedPaymentMethod.trim(),
        bankAccountId: _bankAccountIdForPayment(
          _selectedPaymentMethod,
          widget.setup,
        ),
        financialYear: widget.setup.config.currentFinancialYear,
        voucherType: _selectedVoucherType,
        debitLedgerId: _debitLedgerId(),
        debitLedgerName: _debitLedgerName(),
        creditLedgerId: _creditLedgerId(),
        creditLedgerName: _creditLedgerName(),
        voucherNumber: widget.existingItem?.voucherNumber ?? '',
        reference: _referenceController.text.trim(),
        recordedBy: widget.initialRecordedBy.trim(),
        amount: amount,
        type: _selectedType,
        status: _selectedStatus,
        transactionDate: _selectedDate,
      ),
    );
  }

  String _paymentLedgerName() {
    return _selectedPaymentMethod.trim().isEmpty
        ? 'Cash'
        : _selectedPaymentMethod.trim();
  }

  String _paymentLedgerId() {
    final bankId =
        _bankAccountIdForPayment(_selectedPaymentMethod, widget.setup);
    if (bankId.isNotEmpty) return bankId;
    return 'cash';
  }

  String _debitLedgerName() {
    if (_selectedVoucherType == ChurchVoucherType.receipt) {
      return _paymentLedgerName();
    }
    return _selectedLedger.name;
  }

  String _creditLedgerName() {
    if (_selectedVoucherType == ChurchVoucherType.receipt) {
      return _selectedLedger.name;
    }
    return _paymentLedgerName();
  }

  String _debitLedgerId() {
    if (_selectedVoucherType == ChurchVoucherType.receipt) {
      return _paymentLedgerId();
    }
    return _selectedLedger.id;
  }

  String _creditLedgerId() {
    if (_selectedVoucherType == ChurchVoucherType.receipt) {
      return _selectedLedger.id;
    }
    return _paymentLedgerId();
  }
}

String _currency(double value) {
  return NumberFormat.currency(symbol: 'R ', decimalDigits: 2).format(value);
}

String _date(DateTime value) {
  return DateFormat('MMMM d, y').format(value);
}

String _shortDate(DateTime value) {
  return DateFormat('MMM d, y').format(value);
}

String _slug(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  if (normalized.isEmpty) {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  return normalized;
}

String _sortTextKey(TransactionSortOption value) {
  switch (value) {
    case TransactionSortOption.newestFirst:
      return 'common.sort_newest_first';
    case TransactionSortOption.oldestFirst:
      return 'common.sort_oldest_first';
    case TransactionSortOption.amountHighToLow:
      return 'finance.sort_amount_high_low';
    case TransactionSortOption.amountLowToHigh:
      return 'finance.sort_amount_low_high';
  }
}

List<FinanceLedger> _buildLedgerOptions(
  List<FinanceLedger> ledgers,
  String? selectedLedger,
) {
  final byName = <String, FinanceLedger>{};
  for (final ledger in defaultFinanceLedgers) {
    byName[ledger.name.toLowerCase()] = ledger;
  }
  for (final ledger in ledgers) {
    if (ledger.name.trim().isEmpty) continue;
    byName[ledger.name.toLowerCase()] = ledger;
  }
  if (selectedLedger != null && selectedLedger.trim().isNotEmpty) {
    byName.putIfAbsent(
      selectedLedger.trim().toLowerCase(),
      () => FinanceLedger(
        id: selectedLedger.trim().toLowerCase(),
        name: selectedLedger.trim(),
        group: 'Indirect Income',
      ),
    );
  }
  return byName.values.toList(growable: false)
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

List<String> _paymentMethods(FinanceSetup setup) {
  return <String>{
    'Cash',
    ...setup.banks
        .map((bank) => bank.accountName.trim())
        .where((name) => name.isNotEmpty),
  }.toList(growable: false);
}

String _normalizePaymentMethod(String value, FinanceSetup setup) {
  final options = _paymentMethods(setup);
  final normalized = value.trim();
  if (options.contains(normalized)) return normalized;
  return defaultFinanceLedgers.firstWhere((ledger) => ledger.id == 'cash').name;
}

String _bankAccountIdForPayment(String paymentMethod, FinanceSetup setup) {
  for (final bank in setup.banks) {
    if (bank.accountName.trim() == paymentMethod.trim()) return bank.id;
  }
  return '';
}

Color _typeColor(ChurchTransactionType type) {
  switch (type) {
    case ChurchTransactionType.income:
      return const Color(0xFF28A26A);
    case ChurchTransactionType.expense:
      return const Color(0xFFD66C4A);
  }
}
