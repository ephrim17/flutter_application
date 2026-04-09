import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/church_transaction_model.dart';

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
    required this.isSubmitting,
    required this.query,
    required this.selectedType,
    required this.selectedStatus,
    required this.selectedCategory,
    required this.sortOption,
    required this.visibleTransactionCount,
  })  : categories = _buildCategories(transactions),
        activeFilterCount = _buildActiveFilterCount(
          query: query,
          selectedType: selectedType,
          selectedStatus: selectedStatus,
          selectedCategory: selectedCategory,
        ),
        filteredTransactions = _buildFilteredTransactions(
          transactions: transactions,
          query: query,
          selectedType: selectedType,
          selectedStatus: selectedStatus,
          selectedCategory: selectedCategory,
          sortOption: sortOption,
        ),
        totalIncome = _sumForType(
          transactions,
          ChurchTransactionType.income,
        ),
        totalExpense = _sumForType(
          transactions,
          ChurchTransactionType.expense,
        ),
        pendingAmount = _sumForStatus(
          transactions,
          ChurchTransactionStatus.pending,
        ),
        pendingCount = _countForStatus(
          transactions,
          ChurchTransactionStatus.pending,
        ),
        categorySummaries = _buildCategorySummaries(transactions),
        monthlySummaries = _buildMonthlySummaries(transactions);

  final bool isAdmin;
  final String churchName;
  final List<ChurchTransaction> transactions;
  final bool isSubmitting;
  final String query;
  final String selectedType;
  final String selectedStatus;
  final String selectedCategory;
  final TransactionSortOption sortOption;
  final int visibleTransactionCount;

  final List<String> categories;
  final int activeFilterCount;
  final List<ChurchTransaction> filteredTransactions;
  final double totalIncome;
  final double totalExpense;
  final double pendingAmount;
  final int pendingCount;
  final List<FinancialCategorySummary> categorySummaries;
  final List<MonthlyFinanceSummary> monthlySummaries;

  factory FinancialDashboardViewState.initial({
    required bool isAdmin,
    required String churchName,
  }) {
    return FinancialDashboardViewState(
      isAdmin: isAdmin,
      churchName: churchName,
      transactions: const <ChurchTransaction>[],
      isSubmitting: false,
      query: '',
      selectedType: 'All types',
      selectedStatus: 'All status',
      selectedCategory: 'All categories',
      sortOption: TransactionSortOption.newestFirst,
      visibleTransactionCount: defaultVisibleTransactionCount,
    );
  }

  List<String> get types => <String>[
        'All types',
        ...ChurchTransactionType.values.map((item) => item.label),
      ];

  List<String> get statuses => <String>[
        'All status',
        ...ChurchTransactionStatus.values.map((item) => item.label),
      ];

  double get netBalance => totalIncome - totalExpense;

  int get totalCount => transactions.length;

  int get filteredTransactionCount => filteredTransactions.length;

  bool get hasMoreVisibleTransactions =>
      filteredTransactionCount > pagedTransactions.length;

  List<ChurchTransaction> get pagedTransactions {
    final end = visibleTransactionCount.clamp(0, filteredTransactions.length);
    return filteredTransactions.take(end).toList(growable: false);
  }

  FinancialDashboardViewState copyWith({
    bool? isAdmin,
    String? churchName,
    List<ChurchTransaction>? transactions,
    bool? isSubmitting,
    String? query,
    String? selectedType,
    String? selectedStatus,
    String? selectedCategory,
    TransactionSortOption? sortOption,
    int? visibleTransactionCount,
  }) {
    return FinancialDashboardViewState(
      isAdmin: isAdmin ?? this.isAdmin,
      churchName: churchName ?? this.churchName,
      transactions: transactions ?? this.transactions,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      query: query ?? this.query,
      selectedType: selectedType ?? this.selectedType,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      sortOption: sortOption ?? this.sortOption,
      visibleTransactionCount:
          visibleTransactionCount ?? this.visibleTransactionCount,
    );
  }

  static List<String> _buildCategories(List<ChurchTransaction> transactions) {
    return <String>[
      'All categories',
      ...{
        ..._defaultCategories,
        ...transactions
            .map((item) => item.category.trim())
            .where((item) => item.isNotEmpty),
      },
    ];
  }

  static int _buildActiveFilterCount({
    required String query,
    required String selectedType,
    required String selectedStatus,
    required String selectedCategory,
  }) {
    return (selectedType == 'All types' ? 0 : 1) +
        (selectedStatus == 'All status' ? 0 : 1) +
        (selectedCategory == 'All categories' ? 0 : 1) +
        (query.trim().isEmpty ? 0 : 1);
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
          selectedType == 'All types' || item.type.label == selectedType;
      final matchesStatus =
          selectedStatus == 'All status' || item.status.label == selectedStatus;
      final matchesCategory = selectedCategory == 'All categories' ||
          item.category == selectedCategory;
      final matchesQuery = normalizedQuery.isEmpty ||
          item.title.toLowerCase().contains(normalizedQuery) ||
          item.description.toLowerCase().contains(normalizedQuery) ||
          item.category.toLowerCase().contains(normalizedQuery) ||
          item.paymentMethod.toLowerCase().contains(normalizedQuery) ||
          item.reference.toLowerCase().contains(normalizedQuery) ||
          item.recordedBy.toLowerCase().contains(normalizedQuery);
      return matchesType && matchesStatus && matchesCategory && matchesQuery;
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

  static List<FinancialCategorySummary> _buildCategorySummaries(
    List<ChurchTransaction> transactions,
  ) {
    final grouped = <String, List<ChurchTransaction>>{};
    for (final transaction in transactions) {
      final items = grouped.putIfAbsent(
        transaction.category,
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
    if (value.contains('pledge')) return Icons.handshake_outlined;
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

const List<String> _defaultCategories = <String>[
  'Tithe',
  'Offering',
  'Pledge',
  'Project',
  'Events',
  'Utilities',
];
