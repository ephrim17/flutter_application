import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/church_transaction_model.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/side_drawer/financial_dashboard_view_state.dart';
import 'package:flutter_application/church_app/screens/side_drawer/financial_dashboard_viewmodel.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
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
          title: const AppBarTitle(text: 'Financial Dashboard'),
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: carouselBoxDecoration(context),
            child: Text(
              'Financial dashboard is available only for members of the Finance group.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle(text: 'Financial Dashboard'),
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
                              title: 'Total Income',
                              value: _currency(state.totalIncome),
                              subtitle:
                                  '${state.transactions.where((item) => item.type == ChurchTransactionType.income).length} income records',
                              icon: Icons.arrow_downward_rounded,
                              accent: const Color(0xFF28A26A),
                            ),
                            _FinanceSummaryCard(
                              title: 'Total Expenses',
                              value: _currency(state.totalExpense),
                              subtitle:
                                  '${state.transactions.where((item) => item.type == ChurchTransactionType.expense).length} expense records',
                              icon: Icons.arrow_upward_rounded,
                              accent: const Color(0xFFD66C4A),
                            ),
                            _FinanceSummaryCard(
                              title: 'Current Balance',
                              value: _currency(state.netBalance),
                              subtitle: state.netBalance >= 0
                                  ? 'Healthy runway'
                                  : 'Needs attention',
                              icon: Icons.account_balance_wallet_outlined,
                              accent: const Color(0xFF5878F0),
                            ),
                            _FinanceSummaryCard(
                              title: 'Pending Review',
                              value: _currency(state.pendingAmount),
                              subtitle:
                                  '${state.pendingCount} pending transaction${state.pendingCount == 1 ? '' : 's'}',
                              icon: Icons.pending_actions_outlined,
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
                    child: _DashboardSectionCard(
                      title: 'Category Dashboards',
                      subtitle:
                          'Track how each finance bucket is performing across recorded transactions.',
                      child: state.categorySummaries.isEmpty
                          ? const _FinanceEmptyState(
                              title: 'No category data yet',
                              subtitle:
                                  'Recorded transactions will automatically build category dashboards here.',
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
                                    return _CategoryDashboardTile(
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
                      title: 'Monthly Trends',
                      subtitle:
                          'Income and expense flow across the last six months. Tap a month to inspect its values.',
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
                      title: 'Manage Transactions',
                      subtitle:
                          'Search, filter, and maintain church finance records in one place.',
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
                                label: const Text('Add Transaction'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            variant: AppTextFieldVariant.search,
                            controller: _searchController,
                            onChanged: viewModel.setQuery,
                            decoration: InputDecoration(
                              hintText:
                                  'Search by title, category, payment method, reference, or recorder...',
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
                                      labelText: 'Type',
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
                                      labelText: 'Status',
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
                                      labelText: 'Category',
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
                                      labelText: 'Sort by',
                                      initialValue: state.sortOption,
                                      items: TransactionSortOption.values
                                          .map(
                                            (value) => DropdownMenuItem<
                                                TransactionSortOption>(
                                              value: value,
                                              child: Text(_sortLabel(value)),
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
                                      labelText: 'Type',
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
                                      labelText: 'Status',
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
                                      labelText: 'Category',
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
                                      labelText: 'Sort by',
                                      initialValue: state.sortOption,
                                      items: TransactionSortOption.values
                                          .map(
                                            (value) => DropdownMenuItem<
                                                TransactionSortOption>(
                                              value: value,
                                              child: Text(_sortLabel(value)),
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
                                  '${state.activeFilterCount} active filter${state.activeFilterCount == 1 ? '' : 's'}',
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
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (transactionsAsync.hasError &&
                    state.transactions.isEmpty)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
                    sliver: SliverToBoxAdapter(
                      child: _FinanceEmptyState(
                        title: 'Unable to load transactions',
                        subtitle:
                            'Check your connection or try again in a moment.',
                      ),
                    ),
                  )
                else if (state.filteredTransactionCount == 0)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 100),
                    sliver: SliverToBoxAdapter(
                      child: _FinanceEmptyState(
                        title: 'No matching transactions',
                        subtitle:
                            'Adjust the filters or add a new transaction to get started.',
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
                                  onPressed: state.isSubmitting
                                      ? null
                                      : () {
                                          ref
                                              .read(
                                                financialDashboardViewModelProvider
                                                    .notifier,
                                              )
                                              .showMoreTransactions();
                                        },
                                  icon: const Icon(Icons.expand_more_rounded),
                                  label: Text(
                                    'Load ${FinancialDashboardViewState.defaultVisibleTransactionCount} more',
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
                            'Saving transaction...',
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
    final form = await showModalBottomSheet<ChurchTransactionFormData>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransactionFormSheet(
        initialRecordedBy: currentUserName,
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
        SnackBar(content: Text('Unable to save transaction: $error')),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${form.title} added.')),
    );
  }

  void _showTransactionDetails(BuildContext context, ChurchTransaction item) {
    showModalBottomSheet<void>(
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
                      _MetaPill(label: item.category),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DetailRow(label: 'Amount', value: _currency(item.amount)),
                  _DetailRow(label: 'Date', value: _date(item.transactionDate)),
                  _DetailRow(
                      label: 'Payment Method', value: item.paymentMethod),
                  _DetailRow(
                    label: 'Reference',
                    value: item.reference.trim().isEmpty
                        ? 'Not provided'
                        : item.reference,
                  ),
                  _DetailRow(
                    label: 'Recorded By',
                    value: item.recordedBy.trim().isEmpty
                        ? 'Not provided'
                        : item.recordedBy,
                  ),
                  _DetailRow(
                    label: 'Description',
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
                          label: const Text('Edit'),
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
                          label: const Text('Delete'),
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
    final form = await showModalBottomSheet<ChurchTransactionFormData>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransactionFormSheet(
        existingItem: item,
        initialRecordedBy: item.recordedBy,
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
        SnackBar(content: Text('Unable to update transaction: $error')),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${form.title} updated.')),
    );
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    ChurchTransaction item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('This will permanently remove ${item.title}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
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
        SnackBar(content: Text('Unable to delete transaction: $error')),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.title} deleted.')),
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
                label: 'Finance Team',
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
            'Track offerings, expenses, project spend, and overall cash movement without leaving the app.',
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

class _CategoryDashboardTile extends StatelessWidget {
  const _CategoryDashboardTile({required this.summary});

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
                  '${summary.transactionCount} transaction${summary.transactionCount == 1 ? '' : 's'}',
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
      return const _FinanceEmptyState(
        title: 'No trend data yet',
        subtitle: 'Monthly charts will appear as transactions are recorded.',
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
          children: const [
            _LegendDot(label: 'Income', color: Color(0xFF28A26A)),
            SizedBox(width: 16),
            _LegendDot(label: 'Expenses', color: Color(0xFFD66C4A)),
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
                label: 'Income',
                value: _currency(summary.income),
                color: const Color(0xFF28A26A),
              ),
              _TrendMetricPill(
                label: 'Expenses',
                value: _currency(summary.expense),
                color: const Color(0xFFD66C4A),
              ),
              _TrendMetricPill(
                label: 'Net',
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
                          ? '${item.category} • ${item.paymentMethod}'
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
                        _MetaPill(label: item.category),
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

class _TransactionFormSheet extends StatefulWidget {
  const _TransactionFormSheet({
    this.existingItem,
    required this.initialRecordedBy,
  });

  final ChurchTransaction? existingItem;
  final String initialRecordedBy;

  @override
  State<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _paymentMethodController;
  late final TextEditingController _referenceController;
  late final TextEditingController _amountController;
  late DateTime _selectedDate;
  late ChurchTransactionType _selectedType;
  late ChurchTransactionStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _titleController = TextEditingController(text: item?.title ?? '');
    _descriptionController =
        TextEditingController(text: item?.description ?? '');
    _categoryController =
        TextEditingController(text: item?.category ?? 'Tithe');
    _paymentMethodController =
        TextEditingController(text: item?.paymentMethod ?? 'Cash');
    _referenceController = TextEditingController(text: item?.reference ?? '');
    _amountController = TextEditingController(
      text:
          item != null && item.amount > 0 ? item.amount.toStringAsFixed(2) : '',
    );
    _selectedDate = item?.transactionDate ?? DateTime.now();
    _selectedType = item?.type ?? ChurchTransactionType.income;
    _selectedStatus = item?.status ?? ChurchTransactionStatus.cleared;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _paymentMethodController.dispose();
    _referenceController.dispose();
    _amountController.dispose();
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
                Text(
                  widget.existingItem == null
                      ? 'Add Transaction'
                      : 'Edit Transaction',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Capture income and expenses clearly so admins can keep church finances accurate.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.72),
                      ),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _titleController,
                  label: 'Title',
                  hintText: 'Sunday service offering',
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title'
                      : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hintText: 'Add optional notes',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppDropdownField<ChurchTransactionType>(
                        labelText: 'Type',
                        initialValue: _selectedType,
                        items: ChurchTransactionType.values
                            .map(
                              (value) =>
                                  DropdownMenuItem<ChurchTransactionType>(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedType = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDropdownField<ChurchTransactionStatus>(
                        labelText: 'Status',
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
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _categoryController,
                        label: 'Category',
                        hintText: 'Tithe',
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter a category'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _paymentMethodController,
                        label: 'Payment Method',
                        hintText: 'Cash / Transfer / POS',
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter a payment method'
                                : null,
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
                        label: 'Amount',
                        hintText: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        validator: (value) {
                          final amount = double.tryParse((value ?? '').trim());
                          if (amount == null || amount <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: 'Date',
                        controller:
                            TextEditingController(text: _date(_selectedDate)),
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
                  label: 'Reference',
                  hintText: 'Receipt / bank reference / cheque no.',
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
    setState(() => _selectedDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ChurchTransactionFormData(
        id: widget.existingItem?.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        paymentMethod: _paymentMethodController.text.trim(),
        reference: _referenceController.text.trim(),
        recordedBy: widget.initialRecordedBy.trim(),
        amount: double.parse(_amountController.text.trim()),
        type: _selectedType,
        status: _selectedStatus,
        transactionDate: _selectedDate,
      ),
    );
  }
}

String _currency(double value) {
  return NumberFormat.currency(symbol: 'R ', decimalDigits: 2).format(value);
}

String _date(DateTime value) {
  return DateFormat('MMMM d, y').format(value);
}

String _sortLabel(TransactionSortOption value) {
  switch (value) {
    case TransactionSortOption.newestFirst:
      return 'Newest first';
    case TransactionSortOption.oldestFirst:
      return 'Oldest first';
    case TransactionSortOption.amountHighToLow:
      return 'Amount high to low';
    case TransactionSortOption.amountLowToHigh:
      return 'Amount low to high';
  }
}

Color _typeColor(ChurchTransactionType type) {
  switch (type) {
    case ChurchTransactionType.income:
      return const Color(0xFF28A26A);
    case ChurchTransactionType.expense:
      return const Color(0xFFD66C4A);
  }
}
