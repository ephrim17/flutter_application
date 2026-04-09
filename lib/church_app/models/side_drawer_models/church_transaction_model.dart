import 'package:cloud_firestore/cloud_firestore.dart';

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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isIncome => type == ChurchTransactionType.income;

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
    return ChurchTransaction(
      id: id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? 'General').toString(),
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
      createdAt: createdAt ?? _asNullableDateTime(data['createdAt']),
      updatedAt: updatedAt ?? _asNullableDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'category': category.trim(),
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
