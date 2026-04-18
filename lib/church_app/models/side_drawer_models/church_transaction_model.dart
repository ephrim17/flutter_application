import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceConfig {
  const FinanceConfig({
    this.trustName = '',
    this.registrationNumber = '',
    this.panNumber = '',
    this.mainBankAccountNumber = '',
    this.bankBranchDetails = '',
    this.currentFinancialYear = '',
  });

  final String trustName;
  final String registrationNumber;
  final String panNumber;
  final String mainBankAccountNumber;
  final String bankBranchDetails;
  final String currentFinancialYear;

  factory FinanceConfig.fromMap(Map<String, dynamic> data) {
    return FinanceConfig(
      trustName: (data['trustName'] ?? '').toString(),
      registrationNumber: (data['registrationNumber'] ?? '').toString(),
      panNumber: (data['panNumber'] ?? '').toString(),
      mainBankAccountNumber: (data['mainBankAccountNumber'] ?? '').toString(),
      bankBranchDetails: (data['bankBranchDetails'] ?? '').toString(),
      currentFinancialYear:
          (data['currentFinancialYear'] ?? _defaultFinancialYear()).toString(),
    );
  }

  factory FinanceConfig.empty() {
    return FinanceConfig(currentFinancialYear: _defaultFinancialYear());
  }

  Map<String, dynamic> toMap() {
    return {
      'trustName': trustName.trim(),
      'registrationNumber': registrationNumber.trim(),
      'panNumber': panNumber.trim(),
      'mainBankAccountNumber': mainBankAccountNumber.trim(),
      'bankBranchDetails': bankBranchDetails.trim(),
      'currentFinancialYear': currentFinancialYear.trim(),
    };
  }
}

class FinanceBankAccount {
  const FinanceBankAccount({
    required this.id,
    required this.accountName,
    required this.accountNumber,
    required this.branchDetails,
    required this.isPrimary,
  });

  final String id;
  final String accountName;
  final String accountNumber;
  final String branchDetails;
  final bool isPrimary;

  factory FinanceBankAccount.fromMap(String id, Map<String, dynamic> data) {
    return FinanceBankAccount(
      id: id,
      accountName: (data['accountName'] ?? '').toString(),
      accountNumber: (data['accountNumber'] ?? '').toString(),
      branchDetails: (data['branchDetails'] ?? '').toString(),
      isPrimary: data['isPrimary'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountName': accountName.trim(),
      'accountNumber': accountNumber.trim(),
      'branchDetails': branchDetails.trim(),
      'isPrimary': isPrimary,
    };
  }
}

class FinanceLedger {
  const FinanceLedger({
    required this.id,
    required this.name,
    required this.group,
    this.isSystem = false,
  });

  final String id;
  final String name;
  final String group;
  final bool isSystem;

  factory FinanceLedger.fromMap(String id, Map<String, dynamic> data) {
    return FinanceLedger(
      id: id,
      name: (data['name'] ?? '').toString(),
      group: (data['group'] ?? '').toString(),
      isSystem: data['isSystem'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'group': group.trim(),
      'isSystem': isSystem,
    };
  }
}

class FinanceSetup {
  const FinanceSetup({
    required this.config,
    required this.banks,
    required this.ledgers,
  });

  final FinanceConfig config;
  final List<FinanceBankAccount> banks;
  final List<FinanceLedger> ledgers;

  factory FinanceSetup.empty() {
    return FinanceSetup(
      config: FinanceConfig.empty(),
      banks: const <FinanceBankAccount>[],
      ledgers: defaultFinanceLedgers,
    );
  }

  FinanceSetup copyWith({
    FinanceConfig? config,
    List<FinanceBankAccount>? banks,
    List<FinanceLedger>? ledgers,
  }) {
    return FinanceSetup(
      config: config ?? this.config,
      banks: banks ?? this.banks,
      ledgers: ledgers ?? this.ledgers,
    );
  }
}

class ChurchTransaction {
  const ChurchTransaction({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.paymentMethod,
    required this.reference,
    required this.recordedBy,
    required this.amount,
    required this.type,
    required this.status,
    required this.transactionDate,
    this.partyName = '',
    this.ledgerId = '',
    this.ledgerGroup = '',
    this.bankAccountId = '',
    this.financialYear = '',
    this.voucherType = ChurchVoucherType.receipt,
    this.debitLedgerId = '',
    this.debitLedgerName = '',
    this.creditLedgerId = '',
    this.creditLedgerName = '',
    this.voucherNumber = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String paymentMethod;
  final String reference;
  final String recordedBy;
  final double amount;
  final ChurchTransactionType type;
  final ChurchTransactionStatus status;
  final DateTime transactionDate;
  final String partyName;
  final String ledgerId;
  final String ledgerGroup;
  final String bankAccountId;
  final String financialYear;
  final ChurchVoucherType voucherType;
  final String debitLedgerId;
  final String debitLedgerName;
  final String creditLedgerId;
  final String creditLedgerName;
  final String voucherNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isIncome => type == ChurchTransactionType.income;

  String get ledgerName => category.trim().isEmpty ? 'General' : category;

  factory ChurchTransaction.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return ChurchTransaction.fromData(
      id: id,
      data: data,
      createdAt: _asNullableDateTime(data['createdAt']),
      updatedAt: _asNullableDateTime(data['updatedAt']),
    );
  }

  factory ChurchTransaction.fromData({
    required String id,
    required Map<String, dynamic> data,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final ledgerName =
        (data['ledgerName'] ?? data['category'] ?? 'General').toString();
    return ChurchTransaction(
      id: id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      category: ledgerName,
      paymentMethod: (data['paymentMethod'] ?? 'Cash').toString(),
      reference: (data['reference'] ?? '').toString(),
      recordedBy: (data['recordedBy'] ?? '').toString(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      type: ChurchTransactionTypeX.fromValue(
        (data['type'] ?? 'expense').toString(),
      ),
      status: ChurchTransactionStatusX.fromValue(
        (data['status'] ?? 'cleared').toString(),
      ),
      transactionDate: _asDateTime(data['transactionDate']),
      partyName: (data['partyName'] ?? '').toString(),
      ledgerId: (data['ledgerId'] ?? '').toString(),
      ledgerGroup: (data['ledgerGroup'] ?? '').toString(),
      bankAccountId: (data['bankAccountId'] ?? '').toString(),
      financialYear: (data['financialYear'] ?? '').toString(),
      voucherType: ChurchVoucherTypeX.fromValue(
        (data['voucherType'] ?? '').toString(),
        ChurchTransactionTypeX.fromValue(
          (data['type'] ?? 'expense').toString(),
        ),
      ),
      debitLedgerId: (data['debitLedgerId'] ?? '').toString(),
      debitLedgerName: (data['debitLedgerName'] ?? '').toString(),
      creditLedgerId: (data['creditLedgerId'] ?? '').toString(),
      creditLedgerName: (data['creditLedgerName'] ?? '').toString(),
      voucherNumber: (data['voucherNumber'] ?? '').toString(),
      createdAt: createdAt ?? _asNullableDateTime(data['createdAt']),
      updatedAt: updatedAt ?? _asNullableDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'category': category.trim(),
      'ledgerName': ledgerName.trim(),
      'ledgerId': ledgerId.trim(),
      'ledgerGroup': ledgerGroup.trim(),
      'partyName': partyName.trim(),
      'bankAccountId': bankAccountId.trim(),
      'financialYear': financialYear.trim(),
      'voucherType': voucherType.value,
      'debitLedgerId': debitLedgerId.trim(),
      'debitLedgerName': debitLedgerName.trim(),
      'creditLedgerId': creditLedgerId.trim(),
      'creditLedgerName': creditLedgerName.trim(),
      'voucherNumber': voucherNumber.trim(),
      'paymentMethod': paymentMethod.trim(),
      'reference': reference.trim(),
      'recordedBy': recordedBy.trim(),
      'amount': amount,
      'type': type.value,
      'status': status.value,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

enum ChurchTransactionType {
  income,
  expense,
}

enum ChurchVoucherType {
  receipt,
  payment,
  contra,
  journal,
}

extension ChurchVoucherTypeX on ChurchVoucherType {
  String get value {
    switch (this) {
      case ChurchVoucherType.receipt:
        return 'receipt';
      case ChurchVoucherType.payment:
        return 'payment';
      case ChurchVoucherType.contra:
        return 'contra';
      case ChurchVoucherType.journal:
        return 'journal';
    }
  }

  String get label {
    switch (this) {
      case ChurchVoucherType.receipt:
        return 'Receipt';
      case ChurchVoucherType.payment:
        return 'Payment';
      case ChurchVoucherType.contra:
        return 'Contra';
      case ChurchVoucherType.journal:
        return 'Journal';
    }
  }

  String get friendlyLabel {
    switch (this) {
      case ChurchVoucherType.receipt:
        return 'Money received';
      case ChurchVoucherType.payment:
        return 'Money paid';
      case ChurchVoucherType.contra:
        return 'Cash / bank transfer';
      case ChurchVoucherType.journal:
        return 'Adjustment entry';
    }
  }

  static ChurchVoucherType fromValue(
    String value,
    ChurchTransactionType fallbackType,
  ) {
    switch (value.trim().toLowerCase()) {
      case 'receipt':
        return ChurchVoucherType.receipt;
      case 'payment':
        return ChurchVoucherType.payment;
      case 'contra':
        return ChurchVoucherType.contra;
      case 'journal':
        return ChurchVoucherType.journal;
      default:
        return fallbackType == ChurchTransactionType.income
            ? ChurchVoucherType.receipt
            : ChurchVoucherType.payment;
    }
  }
}

extension ChurchTransactionTypeX on ChurchTransactionType {
  String get value {
    switch (this) {
      case ChurchTransactionType.income:
        return 'income';
      case ChurchTransactionType.expense:
        return 'expense';
    }
  }

  String get label {
    switch (this) {
      case ChurchTransactionType.income:
        return 'Income';
      case ChurchTransactionType.expense:
        return 'Expense';
    }
  }

  static ChurchTransactionType fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'income':
        return ChurchTransactionType.income;
      case 'expense':
      default:
        return ChurchTransactionType.expense;
    }
  }
}

enum ChurchTransactionStatus {
  cleared,
  pending,
}

extension ChurchTransactionStatusX on ChurchTransactionStatus {
  String get value {
    switch (this) {
      case ChurchTransactionStatus.cleared:
        return 'cleared';
      case ChurchTransactionStatus.pending:
        return 'pending';
    }
  }

  String get label {
    switch (this) {
      case ChurchTransactionStatus.cleared:
        return 'Cleared';
      case ChurchTransactionStatus.pending:
        return 'Pending';
    }
  }

  static ChurchTransactionStatus fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'pending':
        return ChurchTransactionStatus.pending;
      case 'cleared':
      default:
        return ChurchTransactionStatus.cleared;
    }
  }
}

class ChurchTransactionFormData {
  const ChurchTransactionFormData({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.paymentMethod,
    required this.reference,
    required this.recordedBy,
    required this.amount,
    required this.type,
    required this.status,
    required this.transactionDate,
    this.partyName = '',
    this.ledgerId = '',
    this.ledgerGroup = '',
    this.bankAccountId = '',
    this.financialYear = '',
    this.voucherType = ChurchVoucherType.receipt,
    this.debitLedgerId = '',
    this.debitLedgerName = '',
    this.creditLedgerId = '',
    this.creditLedgerName = '',
    this.voucherNumber = '',
  });

  final String? id;
  final String title;
  final String description;
  final String category;
  final String paymentMethod;
  final String reference;
  final String recordedBy;
  final double amount;
  final ChurchTransactionType type;
  final ChurchTransactionStatus status;
  final DateTime transactionDate;
  final String partyName;
  final String ledgerId;
  final String ledgerGroup;
  final String bankAccountId;
  final String financialYear;
  final ChurchVoucherType voucherType;
  final String debitLedgerId;
  final String debitLedgerName;
  final String creditLedgerId;
  final String creditLedgerName;
  final String voucherNumber;
}

DateTime _asDateTime(dynamic value) {
  return _asNullableDateTime(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _asNullableDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

String _defaultFinancialYear() {
  final now = DateTime.now();
  final startYear = now.month >= 4 ? now.year : now.year - 1;
  return '$startYear-${startYear + 1}';
}

const List<String> financeLedgerGroups = <String>[
  'Current Assets',
  'Fixed Assets',
  'Direct Expenses',
  'Indirect Expenses',
  'Direct Income',
  'Indirect Income',
  'Cash in Hand',
  'Bank Accounts',
  'Current Liabilities',
  'Deposit Assets',
  'Capital Account',
  'Duties & Taxes',
  'Deposits',
  'Loans (Liability & Asset)',
];

const List<FinanceLedger> defaultFinanceLedgers = <FinanceLedger>[
  FinanceLedger(
    id: 'tithe',
    name: 'Tithe',
    group: 'Direct Income',
    isSystem: true,
  ),
  FinanceLedger(
    id: 'offering',
    name: 'Offering',
    group: 'Direct Income',
    isSystem: true,
  ),
  FinanceLedger(
    id: 'pledge',
    name: 'Pledge',
    group: 'Direct Income',
    isSystem: true,
  ),
  FinanceLedger(
    id: 'project',
    name: 'Project',
    group: 'Direct Income',
    isSystem: true,
  ),
  FinanceLedger(
    id: 'events',
    name: 'Events',
    group: 'Indirect Income',
    isSystem: true,
  ),
  FinanceLedger(
    id: 'utilities',
    name: 'Utilities',
    group: 'Indirect Expenses',
    isSystem: true,
  ),
  FinanceLedger(
    id: 'cash',
    name: 'Cash',
    group: 'Cash in Hand',
    isSystem: true,
  ),
];
