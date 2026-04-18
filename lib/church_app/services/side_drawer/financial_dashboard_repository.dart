import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/church_transaction_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final financialDashboardRepositoryProvider =
    Provider<FinancialDashboardRepository>((_) {
  return FinancialDashboardRepository(
    functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
  );
});

class FinancialDashboardRepository {
  FinancialDashboardRepository({required this.functions});

  final FirebaseFunctions functions;

  Future<FinanceSetup> fetchSetup(String churchId) async {
    final callable = functions.httpsCallable('getFinancialSetup');
    final response = await callable.call(<String, dynamic>{
      'churchId': churchId,
    });

    final data = Map<String, dynamic>.from(response.data as Map);
    final rawBanks = (data['banks'] as List?) ?? const [];
    final rawLedgers = (data['ledgers'] as List?) ?? const [];
    final customLedgers = rawLedgers
        .map((item) => FinanceLedger.fromMap(
              (item as Map)['id']?.toString() ?? '',
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.name.trim().isNotEmpty)
        .toList(growable: false);

    return FinanceSetup(
      config: FinanceConfig.fromMap(
        Map<String, dynamic>.from((data['config'] as Map?) ?? const {}),
      ),
      banks: rawBanks
          .map((item) => FinanceBankAccount.fromMap(
                (item as Map)['id']?.toString() ?? '',
                Map<String, dynamic>.from(item),
              ))
          .where((item) => item.accountName.trim().isNotEmpty)
          .toList(growable: false),
      ledgers: _mergeLedgers(customLedgers),
    );
  }

  Future<void> saveConfig({
    required String churchId,
    required FinanceConfig config,
  }) async {
    final callable = functions.httpsCallable('saveFinancialConfig');
    await callable.call(<String, dynamic>{
      'churchId': churchId,
      'config': config.toMap(),
    });
  }

  Future<void> upsertBank({
    required String churchId,
    required FinanceBankAccount bank,
  }) async {
    final callable = functions.httpsCallable('upsertFinancialBank');
    await callable.call(<String, dynamic>{
      'churchId': churchId,
      'bankId': bank.id,
      'bank': bank.toMap(),
    });
  }

  Future<void> deleteBank({
    required String churchId,
    required FinanceBankAccount bank,
  }) async {
    final callable = functions.httpsCallable('deleteFinancialBank');
    await callable.call(<String, dynamic>{
      'churchId': churchId,
      'bankId': bank.id,
    });
  }

  Future<void> upsertLedger({
    required String churchId,
    required FinanceLedger ledger,
  }) async {
    final callable = functions.httpsCallable('upsertFinancialLedger');
    await callable.call(<String, dynamic>{
      'churchId': churchId,
      'ledgerId': ledger.id,
      'ledger': ledger.toMap(),
    });
  }

  Future<List<ChurchTransaction>> fetchTransactions(String churchId) async {
    final callable = functions.httpsCallable('getFinancialTransactions');
    final response = await callable.call(<String, dynamic>{
      'churchId': churchId,
    });

    final data = Map<String, dynamic>.from(response.data as Map);
    final rawItems = (data['transactions'] as List?) ?? const [];
    return rawItems
        .map(
          (item) => _deserializeTransaction(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> createTransaction({
    required String churchId,
    required ChurchTransactionFormData form,
  }) async {
    final callable = functions.httpsCallable('upsertFinancialTransaction');
    await callable.call(<String, dynamic>{
      'churchId': churchId,
      'transaction': _serializeForm(form),
    });
  }

  Future<void> updateTransaction({
    required String churchId,
    required ChurchTransactionFormData form,
  }) async {
    final transactionId = form.id;
    if (transactionId == null || transactionId.trim().isEmpty) {
      throw StateError('Transaction id is required for update.');
    }

    final callable = functions.httpsCallable('upsertFinancialTransaction');
    await callable.call(<String, dynamic>{
      'churchId': churchId,
      'transactionId': transactionId,
      'transaction': _serializeForm(form),
    });
  }

  Future<void> deleteTransaction({
    required String churchId,
    required ChurchTransaction item,
  }) async {
    final callable = functions.httpsCallable('deleteFinancialTransaction');
    await callable.call(<String, dynamic>{
      'churchId': churchId,
      'transactionId': item.id,
    });
  }

  Map<String, dynamic> _serializeForm(ChurchTransactionFormData form) {
    return <String, dynamic>{
      'title': form.title.trim(),
      'description': form.description.trim(),
      'category': form.category.trim(),
      'ledgerName': form.category.trim(),
      'ledgerId': form.ledgerId.trim(),
      'ledgerGroup': form.ledgerGroup.trim(),
      'partyName': form.partyName.trim(),
      'bankAccountId': form.bankAccountId.trim(),
      'financialYear': form.financialYear.trim(),
      'voucherType': form.voucherType.value,
      'debitLedgerId': form.debitLedgerId.trim(),
      'debitLedgerName': form.debitLedgerName.trim(),
      'creditLedgerId': form.creditLedgerId.trim(),
      'creditLedgerName': form.creditLedgerName.trim(),
      'voucherNumber': form.voucherNumber.trim(),
      'paymentMethod': form.paymentMethod.trim(),
      'reference': form.reference.trim(),
      'recordedBy': form.recordedBy.trim(),
      'amount': form.amount,
      'type': form.type.value,
      'status': form.status.value,
      'transactionDateMillis': form.transactionDate.millisecondsSinceEpoch,
    };
  }

  ChurchTransaction _deserializeTransaction(Map<String, dynamic> data) {
    final createdAtMillis = (data['createdAtMillis'] as num?)?.toInt();
    final updatedAtMillis = (data['updatedAtMillis'] as num?)?.toInt();
    return ChurchTransaction.fromData(
      id: (data['id'] ?? '').toString(),
      data: <String, dynamic>{
        'title': data['title'],
        'description': data['description'],
        'category': data['category'],
        'ledgerName': data['ledgerName'],
        'ledgerId': data['ledgerId'],
        'ledgerGroup': data['ledgerGroup'],
        'partyName': data['partyName'],
        'bankAccountId': data['bankAccountId'],
        'financialYear': data['financialYear'],
        'voucherType': data['voucherType'],
        'debitLedgerId': data['debitLedgerId'],
        'debitLedgerName': data['debitLedgerName'],
        'creditLedgerId': data['creditLedgerId'],
        'creditLedgerName': data['creditLedgerName'],
        'voucherNumber': data['voucherNumber'],
        'paymentMethod': data['paymentMethod'],
        'reference': data['reference'],
        'recordedBy': data['recordedBy'],
        'amount': data['amount'],
        'type': data['type'],
        'status': data['status'],
        'transactionDate': DateTime.fromMillisecondsSinceEpoch(
          (data['transactionDateMillis'] as num?)?.toInt() ?? 0,
        ),
      },
      createdAt: createdAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
      updatedAt: updatedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updatedAtMillis),
    );
  }

  List<FinanceLedger> _mergeLedgers(List<FinanceLedger> customLedgers) {
    final byKey = <String, FinanceLedger>{};
    for (final ledger in defaultFinanceLedgers) {
      byKey[ledger.name.toLowerCase()] = ledger;
    }
    for (final ledger in customLedgers) {
      byKey[ledger.name.toLowerCase()] = ledger;
    }
    return byKey.values.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}
