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
}
