import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/church_transaction_model.dart';
import 'package:flutter_application/church_app/services/side_drawer/financial_dashboard_repository.dart';

const String allTypesFilter = 'All types';
const String allStatusFilter = 'All status';
const String allLedgersFilter = 'All ledgers';

enum TransactionSortOption {
  newestFirst,
  oldestFirst,
  amountHighToLow,
  amountLowToHigh,
}

class FinancialDashboardViewState {
  static const int defaultVisibleTransactionCount = 25;

  FinancialDashboardViewState({
    required this.isAdmin,
    required this.churchName,
    required this.transactions,
    required this.setup,
    required this.isSubmitting,
    required this.isLoadingMoreTransactions,
    required this.hasMoreRemoteTransactions,
    required this.nextTransactionCursor,
    required this.query,
    required this.selectedType,
    required this.selectedStatus,
    required this.selectedCategory,
    required this.sortOption,
    required this.visibleTransactionCount,
    required this.dayBookStartDate,
    required this.dayBookEndDate,
  })  : ledgers = _buildLedgers(setup.ledgers, transactions),
        categories = _buildLedgerNames(setup.ledgers, transactions),
        activeFilterCount = _buildActiveFilterCount(
          query: query,
          selectedType: selectedType,
          selectedStatus: selectedStatus,
          selectedCategory: selectedCategory,
        ),
        financialYearTransactions = _buildFinancialYearTransactions(
          transactions: transactions,
          financialYear: setup.config.currentFinancialYear,
        ),
        filteredTransactions = _buildFilteredTransactions(
          transactions: _buildFinancialYearTransactions(
            transactions: transactions,
            financialYear: setup.config.currentFinancialYear,
          ),
          query: query,
          selectedType: selectedType,
          selectedStatus: selectedStatus,
          selectedCategory: selectedCategory,
          sortOption: sortOption,
        ),
        totalIncome = _sumForType(
          _buildFinancialYearTransactions(
            transactions: transactions,
            financialYear: setup.config.currentFinancialYear,
          ),
          ChurchTransactionType.income,
        ),
        totalExpense = _sumForType(
          _buildFinancialYearTransactions(
            transactions: transactions,
            financialYear: setup.config.currentFinancialYear,
          ),
          ChurchTransactionType.expense,
        ),
        pendingAmount = _sumForStatus(
          _buildFinancialYearTransactions(
            transactions: transactions,
            financialYear: setup.config.currentFinancialYear,
          ),
          ChurchTransactionStatus.pending,
        ),
        pendingCount = _countForStatus(
          _buildFinancialYearTransactions(
            transactions: transactions,
            financialYear: setup.config.currentFinancialYear,
          ),
          ChurchTransactionStatus.pending,
        ),
        categorySummaries = _buildCategorySummaries(
          _buildFinancialYearTransactions(
            transactions: transactions,
            financialYear: setup.config.currentFinancialYear,
          ),
        ),
        monthlySummaries = _buildMonthlySummaries(
          _buildFinancialYearTransactions(
            transactions: transactions,
            financialYear: setup.config.currentFinancialYear,
          ),
        ),
        dayBookTransactions = _buildDayBookTransactions(
          transactions: _buildFinancialYearTransactions(
            transactions: transactions,
            financialYear: setup.config.currentFinancialYear,
          ),
          startDate: dayBookStartDate,
          endDate: dayBookEndDate,
        ),
        trialBalanceRows = _buildTrialBalanceRows(
          transactions: _buildFinancialYearTransactions(
            transactions: transactions,
            financialYear: setup.config.currentFinancialYear,
          ),
        ),
        ledgerStatementRows = _buildLedgerStatementRows(
          transactions: _buildFinancialYearTransactions(
            transactions: transactions,
            financialYear: setup.config.currentFinancialYear,
          ),
        );

  final bool isAdmin;
  final String churchName;
  final List<ChurchTransaction> transactions;
  final FinanceSetup setup;
  final bool isSubmitting;
  final bool isLoadingMoreTransactions;
  final bool hasMoreRemoteTransactions;
  final FinancialTransactionCursor? nextTransactionCursor;
  final String query;
  final String selectedType;
  final String selectedStatus;
  final String selectedCategory;
  final TransactionSortOption sortOption;
  final int visibleTransactionCount;
  final DateTime dayBookStartDate;
  final DateTime dayBookEndDate;

  final List<FinanceLedger> ledgers;
  final List<String> categories;
  final int activeFilterCount;
  final List<ChurchTransaction> financialYearTransactions;
  final List<ChurchTransaction> filteredTransactions;
  final double totalIncome;
  final double totalExpense;
  final double pendingAmount;
  final int pendingCount;
  final List<FinancialCategorySummary> categorySummaries;
  final List<MonthlyFinanceSummary> monthlySummaries;
  final List<ChurchTransaction> dayBookTransactions;
  final List<TrialBalanceRow> trialBalanceRows;
  final List<LedgerStatementRow> ledgerStatementRows;

  factory FinancialDashboardViewState.initial({
    required bool isAdmin,
    required String churchName,
  }) {
    final now = DateTime.now();
    return FinancialDashboardViewState(
      isAdmin: isAdmin,
      churchName: churchName,
      transactions: const <ChurchTransaction>[],
      setup: FinanceSetup.empty(),
      isSubmitting: false,
      isLoadingMoreTransactions: false,
      hasMoreRemoteTransactions: false,
      nextTransactionCursor: null,
      query: '',
      selectedType: allTypesFilter,
      selectedStatus: allStatusFilter,
      selectedCategory: allLedgersFilter,
      sortOption: TransactionSortOption.newestFirst,
      visibleTransactionCount: defaultVisibleTransactionCount,
      dayBookStartDate: DateTime(now.year, now.month, 1),
      dayBookEndDate: now,
    );
  }

  List<String> get types => <String>[
        allTypesFilter,
        ...ChurchTransactionType.values.map((item) => item.label),
      ];

  List<String> get statuses => <String>[
        allStatusFilter,
        ...ChurchTransactionStatus.values.map((item) => item.label),
      ];

  double get netBalance => totalIncome - totalExpense;

  double get bankBalance => _sumBankTransactions(financialYearTransactions);

  double get cashInHand => financialYearTransactions
      .where((item) => item.paymentMethod.toLowerCase() == 'cash')
      .fold(0.0, _balanceReducer);

  int get totalCount => financialYearTransactions.length;

  int get filteredTransactionCount => filteredTransactions.length;

  double get dayBookIncome =>
      _sumForType(dayBookTransactions, ChurchTransactionType.income);

  double get dayBookExpense =>
      _sumForType(dayBookTransactions, ChurchTransactionType.expense);

  double get dayBookClosingBalance => dayBookIncome - dayBookExpense;

  double get trialDebitTotal =>
      trialBalanceRows.fold(0.0, (sum, row) => sum + row.debit);

  double get trialCreditTotal =>
      trialBalanceRows.fold(0.0, (sum, row) => sum + row.credit);

  List<LedgerStatementRow> get cashBookRows => ledgerStatementRows
      .where((row) => row.ledgerName.toLowerCase() == 'cash')
      .toList(growable: false);

  List<LedgerStatementRow> get bankBookRows => ledgerStatementRows
      .where((row) => row.ledgerGroup.toLowerCase() == 'bank accounts')
      .toList(growable: false);

  bool get hasMoreVisibleTransactions =>
      filteredTransactionCount > pagedTransactions.length ||
      hasMoreRemoteTransactions;

  List<ChurchTransaction> get pagedTransactions {
    final end = visibleTransactionCount.clamp(0, filteredTransactions.length);
    return filteredTransactions.take(end).toList(growable: false);
  }

  FinancialDashboardViewState copyWith({
    bool? isAdmin,
    String? churchName,
    List<ChurchTransaction>? transactions,
    FinanceSetup? setup,
    bool? isSubmitting,
    bool? isLoadingMoreTransactions,
    bool? hasMoreRemoteTransactions,
    FinancialTransactionCursor? nextTransactionCursor,
    bool clearNextTransactionCursor = false,
    String? query,
    String? selectedType,
    String? selectedStatus,
    String? selectedCategory,
    TransactionSortOption? sortOption,
    int? visibleTransactionCount,
    DateTime? dayBookStartDate,
    DateTime? dayBookEndDate,
  }) {
    return FinancialDashboardViewState(
      isAdmin: isAdmin ?? this.isAdmin,
      churchName: churchName ?? this.churchName,
      transactions: transactions ?? this.transactions,
      setup: setup ?? this.setup,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLoadingMoreTransactions:
          isLoadingMoreTransactions ?? this.isLoadingMoreTransactions,
      hasMoreRemoteTransactions:
          hasMoreRemoteTransactions ?? this.hasMoreRemoteTransactions,
      nextTransactionCursor: clearNextTransactionCursor
          ? null
          : nextTransactionCursor ?? this.nextTransactionCursor,
      query: query ?? this.query,
      selectedType: selectedType ?? this.selectedType,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      sortOption: sortOption ?? this.sortOption,
      visibleTransactionCount:
          visibleTransactionCount ?? this.visibleTransactionCount,
      dayBookStartDate: dayBookStartDate ?? this.dayBookStartDate,
      dayBookEndDate: dayBookEndDate ?? this.dayBookEndDate,
    );
  }

  static List<FinanceLedger> _buildLedgers(
    List<FinanceLedger> setupLedgers,
    List<ChurchTransaction> transactions,
  ) {
    final byName = <String, FinanceLedger>{};
    for (final ledger in defaultFinanceLedgers) {
      byName[ledger.name.toLowerCase()] = ledger;
    }
    for (final ledger in setupLedgers) {
      if (ledger.name.trim().isEmpty) continue;
      byName[ledger.name.toLowerCase()] = ledger;
    }
    for (final transaction in transactions) {
      final name = transaction.ledgerName.trim();
      if (name.isEmpty || byName.containsKey(name.toLowerCase())) continue;
      byName[name.toLowerCase()] = FinanceLedger(
        id: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
        name: name,
        group: transaction.ledgerGroup.trim().isEmpty
            ? 'Indirect Income'
            : transaction.ledgerGroup.trim(),
      );
    }
    return byName.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static List<String> _buildLedgerNames(
    List<FinanceLedger> setupLedgers,
    List<ChurchTransaction> transactions,
  ) {
    return <String>[
      allLedgersFilter,
      ..._buildLedgers(setupLedgers, transactions).map((item) => item.name),
    ];
  }

  static int _buildActiveFilterCount({
    required String query,
    required String selectedType,
    required String selectedStatus,
    required String selectedCategory,
  }) {
    return (selectedType == allTypesFilter ? 0 : 1) +
        (selectedStatus == allStatusFilter ? 0 : 1) +
        (selectedCategory == allLedgersFilter ? 0 : 1) +
        (query.trim().isEmpty ? 0 : 1);
  }

  static List<ChurchTransaction> _buildFinancialYearTransactions({
    required List<ChurchTransaction> transactions,
    required String financialYear,
  }) {
    final range = FinancialYearRange.fromLabel(financialYear);
    return transactions.where((item) {
      final explicitYear = item.financialYear.trim();
      if (explicitYear.isNotEmpty) return explicitYear == financialYear;
      return !item.transactionDate.isBefore(range.start) &&
          item.transactionDate.isBefore(range.endExclusive);
    }).toList(growable: false);
  }

  static List<ChurchTransaction> _buildFilteredTransactions({
    required List<ChurchTransaction> transactions,
    required String query,
    required String selectedType,
    required String selectedStatus,
    required String selectedCategory,
    required TransactionSortOption sortOption,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = transactions.where((item) {
      final matchesType =
          selectedType == allTypesFilter || item.type.label == selectedType;
      final matchesStatus = selectedStatus == allStatusFilter ||
          item.status.label == selectedStatus;
      final matchesLedger = selectedCategory == allLedgersFilter ||
          item.ledgerName == selectedCategory;
      final matchesQuery = normalizedQuery.isEmpty ||
          item.title.toLowerCase().contains(normalizedQuery) ||
          item.description.toLowerCase().contains(normalizedQuery) ||
          item.ledgerName.toLowerCase().contains(normalizedQuery) ||
          item.partyName.toLowerCase().contains(normalizedQuery) ||
          item.paymentMethod.toLowerCase().contains(normalizedQuery) ||
          item.reference.toLowerCase().contains(normalizedQuery) ||
          item.recordedBy.toLowerCase().contains(normalizedQuery);
      return matchesType && matchesStatus && matchesLedger && matchesQuery;
    }).toList(growable: false);

    filtered.sort((a, b) {
      switch (sortOption) {
        case TransactionSortOption.newestFirst:
          return b.transactionDate.compareTo(a.transactionDate);
        case TransactionSortOption.oldestFirst:
          return a.transactionDate.compareTo(b.transactionDate);
        case TransactionSortOption.amountHighToLow:
          return b.amount.compareTo(a.amount);
        case TransactionSortOption.amountLowToHigh:
          return a.amount.compareTo(b.amount);
      }
    });

    return filtered;
  }

  static List<ChurchTransaction> _buildDayBookTransactions({
    required List<ChurchTransaction> transactions,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final endExclusive = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).add(const Duration(days: 1));
    return transactions.where((item) {
      return !item.transactionDate.isBefore(start) &&
          item.transactionDate.isBefore(endExclusive);
    }).toList(growable: false)
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
  }

  static List<TrialBalanceRow> _buildTrialBalanceRows({
    required List<ChurchTransaction> transactions,
  }) {
    final rows = <String, TrialBalanceRowAccumulator>{};
    for (final transaction in transactions) {
      final debitName = _effectiveDebitLedgerName(transaction);
      final creditName = _effectiveCreditLedgerName(transaction);
      final debitGroup = _effectiveDebitLedgerGroup(transaction);
      final creditGroup = _effectiveCreditLedgerGroup(transaction);
      rows
          .putIfAbsent(
            debitName,
            () => TrialBalanceRowAccumulator(debitName, debitGroup),
          )
          .debit += transaction.amount;
      rows
          .putIfAbsent(
            creditName,
            () => TrialBalanceRowAccumulator(creditName, creditGroup),
          )
          .credit += transaction.amount;
    }
    return rows.values
        .map(
          (row) => TrialBalanceRow(
            ledgerName: row.ledgerName,
            ledgerGroup: row.ledgerGroup,
            debit: row.debit,
            credit: row.credit,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.ledgerName.compareTo(b.ledgerName));
  }

  static List<LedgerStatementRow> _buildLedgerStatementRows({
    required List<ChurchTransaction> transactions,
  }) {
    final rows = <LedgerStatementRow>[];
    final runningBalances = <String, double>{};
    final sorted = [...transactions]
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
    for (final transaction in sorted) {
      final debitName = _effectiveDebitLedgerName(transaction);
      final creditName = _effectiveCreditLedgerName(transaction);
      final debitGroup = _effectiveDebitLedgerGroup(transaction);
      final creditGroup = _effectiveCreditLedgerGroup(transaction);
      final debitBalance =
          (runningBalances[debitName] ?? 0) + transaction.amount;
      runningBalances[debitName] = debitBalance;
      rows.add(
        LedgerStatementRow(
          transaction: transaction,
          ledgerName: debitName,
          ledgerGroup: debitGroup,
          debit: transaction.amount,
          credit: 0,
          runningBalance: debitBalance,
        ),
      );

      final creditBalance =
          (runningBalances[creditName] ?? 0) - transaction.amount;
      runningBalances[creditName] = creditBalance;
      rows.add(
        LedgerStatementRow(
          transaction: transaction,
          ledgerName: creditName,
          ledgerGroup: creditGroup,
          debit: 0,
          credit: transaction.amount,
          runningBalance: creditBalance,
        ),
      );
    }
    return rows;
  }

  static String _effectiveDebitLedgerName(ChurchTransaction transaction) {
    if (transaction.debitLedgerName.trim().isNotEmpty) {
      return transaction.debitLedgerName.trim();
    }
    if (transaction.type == ChurchTransactionType.income) {
      return transaction.paymentMethod.trim().isEmpty
          ? 'Cash'
          : transaction.paymentMethod.trim();
    }
    return transaction.ledgerName;
  }

  static String _effectiveCreditLedgerName(ChurchTransaction transaction) {
    if (transaction.creditLedgerName.trim().isNotEmpty) {
      return transaction.creditLedgerName.trim();
    }
    if (transaction.type == ChurchTransactionType.income) {
      return transaction.ledgerName;
    }
    return transaction.paymentMethod.trim().isEmpty
        ? 'Cash'
        : transaction.paymentMethod.trim();
  }

  static String _effectiveDebitLedgerGroup(ChurchTransaction transaction) {
    if (transaction.type == ChurchTransactionType.income) {
      return transaction.paymentMethod.toLowerCase() == 'cash'
          ? 'Cash in Hand'
          : 'Bank Accounts';
    }
    return transaction.ledgerGroup.trim().isEmpty
        ? 'Indirect Expenses'
        : transaction.ledgerGroup.trim();
  }

  static String _effectiveCreditLedgerGroup(ChurchTransaction transaction) {
    if (transaction.type == ChurchTransactionType.income) {
      return transaction.ledgerGroup.trim().isEmpty
          ? 'Direct Income'
          : transaction.ledgerGroup.trim();
    }
    return transaction.paymentMethod.toLowerCase() == 'cash'
        ? 'Cash in Hand'
        : 'Bank Accounts';
  }

  static double _sumForType(
    List<ChurchTransaction> transactions,
    ChurchTransactionType type,
  ) {
    return transactions
        .where((item) => item.type == type)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  static double _sumForStatus(
    List<ChurchTransaction> transactions,
    ChurchTransactionStatus status,
  ) {
    return transactions
        .where((item) => item.status == status)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  static int _countForStatus(
    List<ChurchTransaction> transactions,
    ChurchTransactionStatus status,
  ) {
    return transactions.where((item) => item.status == status).length;
  }

  static double _sumBankTransactions(List<ChurchTransaction> transactions) {
    return transactions
        .where((item) => item.paymentMethod.toLowerCase() != 'cash')
        .fold(0.0, _balanceReducer);
  }

  static double _balanceReducer(double sum, ChurchTransaction item) {
    return item.type == ChurchTransactionType.income
        ? sum + item.amount
        : sum - item.amount;
  }

  static List<FinancialCategorySummary> _buildCategorySummaries(
    List<ChurchTransaction> transactions,
  ) {
    final grouped = <String, List<ChurchTransaction>>{};
    for (final transaction in transactions) {
      final items = grouped.putIfAbsent(
        transaction.ledgerName,
        () => <ChurchTransaction>[],
      );
      items.add(transaction);
    }

    return grouped.entries.map((entry) {
      final items = entry.value;
      final income = items
          .where((item) => item.type == ChurchTransactionType.income)
          .fold(0.0, (sum, item) => sum + item.amount);
      final expense = items
          .where((item) => item.type == ChurchTransactionType.expense)
          .fold(0.0, (sum, item) => sum + item.amount);
      return FinancialCategorySummary(
        name: entry.key,
        income: income,
        expense: expense,
        transactionCount: items.length,
      );
    }).toList(growable: false)
      ..sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
  }

  static List<MonthlyFinanceSummary> _buildMonthlySummaries(
    List<ChurchTransaction> transactions,
  ) {
    final now = DateTime.now();
    final months = List.generate(6, (index) {
      final date = DateTime(now.year, now.month - (5 - index), 1);
      return DateTime(date.year, date.month, 1);
    });

    return months.map((month) {
      var income = 0.0;
      var expense = 0.0;
      for (final item in transactions) {
        if (item.transactionDate.year == month.year &&
            item.transactionDate.month == month.month) {
          if (item.type == ChurchTransactionType.income) {
            income += item.amount;
          } else {
            expense += item.amount;
          }
        }
      }
      return MonthlyFinanceSummary(
        month: month,
        income: income,
        expense: expense,
      );
    }).toList(growable: false);
  }
}

class FinancialYearRange {
  const FinancialYearRange({required this.start, required this.endExclusive});

  final DateTime start;
  final DateTime endExclusive;

  factory FinancialYearRange.fromLabel(String value) {
    final match = RegExp(r'(\d{4})').firstMatch(value);
    final startYear =
        int.tryParse(match?.group(1) ?? '') ?? DateTime.now().year;
    return FinancialYearRange(
      start: DateTime(startYear, 4),
      endExclusive: DateTime(startYear + 1, 4),
    );
  }
}

class FinancialCategorySummary {
  const FinancialCategorySummary({
    required this.name,
    required this.income,
    required this.expense,
    required this.transactionCount,
  });

  final String name;
  final double income;
  final double expense;
  final int transactionCount;

  double get balance => income - expense;
  double get totalVolume => income + expense;

  bool get isExpenseHeavy => expense > income;

  IconData get icon {
    final value = name.toLowerCase();
    if (value.contains('tithe')) return Icons.volunteer_activism_outlined;
    if (value.contains('offering')) return Icons.favorite_outline_rounded;
    if (value.contains('project')) return Icons.cottage_outlined;
    if (value.contains('event')) return Icons.event_outlined;
    if (value.contains('utility')) return Icons.bolt_outlined;
    return Icons.account_balance_wallet_outlined;
  }
}

class MonthlyFinanceSummary {
  const MonthlyFinanceSummary({
    required this.month,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final double income;
  final double expense;

  double get total => income + expense;
}

class TrialBalanceRowAccumulator {
  TrialBalanceRowAccumulator(this.ledgerName, this.ledgerGroup);

  final String ledgerName;
  final String ledgerGroup;
  double debit = 0;
  double credit = 0;
}

class TrialBalanceRow {
  const TrialBalanceRow({
    required this.ledgerName,
    required this.ledgerGroup,
    required this.debit,
    required this.credit,
  });

  final String ledgerName;
  final String ledgerGroup;
  final double debit;
  final double credit;

  double get balance => debit - credit;
}

class LedgerStatementRow {
  const LedgerStatementRow({
    required this.transaction,
    required this.ledgerName,
    required this.ledgerGroup,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });

  final ChurchTransaction transaction;
  final String ledgerName;
  final String ledgerGroup;
  final double debit;
  final double credit;
  final double runningBalance;
}
