// Foreign vendor sub-ledger, aging and credit limit providers (Trello GzFff0Pc).
// Every read is autoDispose: opening the dialog always loads fresh data from the server (the backend refreshes
// the sub-ledger from its sources on read). Mutations invalidate all three views of the supplier.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../audit_logs/providers/audit_logs_provider.dart';
import '../models/supplier_ledger_model.dart';
import 'suppliers_provider.dart';

typedef SupplierStatementQuery = ({int supplierId, String? currency});

String _supplierUrl(int supplierId) => '${ApiConstants.baseUrl}/suppliers/$supplierId';

Map<String, dynamic> _asMap(dynamic data) =>
    data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

final supplierStatementProvider =
    FutureProvider.autoDispose.family<SupplierStatement, SupplierStatementQuery>((ref, query) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get(
    '${_supplierUrl(query.supplierId)}/ledger/statement',
    queryParameters: {if (query.currency != null && query.currency!.isNotEmpty) 'currency': query.currency},
  );
  return SupplierStatement.fromJson(_asMap(res.data));
});

final supplierAgingProvider = FutureProvider.autoDispose.family<SupplierAging, int>((ref, supplierId) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('${_supplierUrl(supplierId)}/ledger/aging');
  return SupplierAging.fromJson(_asMap(res.data));
});

final supplierCreditStatusProvider =
    FutureProvider.autoDispose.family<SupplierCreditStatus, int>((ref, supplierId) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('${_supplierUrl(supplierId)}/credit-limit');
  return SupplierCreditStatus.fromJson(_asMap(res.data));
});

final supplierLedgerActionsProvider = Provider<SupplierLedgerActions>((ref) => SupplierLedgerActions(ref));

/// Mutations of the sub-ledger screen. Each one invalidates the statement, aging and credit views of the
/// supplier (plus the audit logs) so the next frame reloads from the server.
class SupplierLedgerActions {
  final Ref _ref;

  SupplierLedgerActions(this._ref);

  Dio get _dio => _ref.read(dioProvider);

  void invalidateSupplier(int supplierId) {
    _ref.invalidate(supplierStatementProvider);
    _ref.invalidate(supplierAgingProvider(supplierId));
    _ref.invalidate(supplierCreditStatusProvider(supplierId));
    _ref.invalidate(systemAuditLogsProvider);
  }

  /// Rebuilds the sub-ledger from the sources (invoices, payments, LC / CAD instruments).
  Future<void> syncLedger(int supplierId) async {
    await _dio.post('${_supplierUrl(supplierId)}/ledger/sync');
    invalidateSupplier(supplierId);
  }

  Future<void> updateCreditLimit(
    int supplierId, {
    required double creditLimit,
    String? currency,
    required String policy,
  }) async {
    await _dio.put('${_supplierUrl(supplierId)}/credit-limit', data: {
      'credit_limit': creditLimit,
      'credit_limit_currency': currency,
      'credit_limit_policy': policy,
    });
    invalidateSupplier(supplierId);
    _ref.invalidate(suppliersProvider);
  }

  Future<SupplierCreditCheck> checkCredit(int supplierId, {required double amount, String? currency}) async {
    final res = await _dio.post('${_supplierUrl(supplierId)}/credit-limit/check', data: {
      'amount': amount,
      if (currency != null) 'currency': currency,
    });
    return SupplierCreditCheck.fromJson(_asMap(res.data));
  }
}
