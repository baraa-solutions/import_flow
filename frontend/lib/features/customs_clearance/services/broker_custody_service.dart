import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/broker_custody_model.dart';

final brokerCustodyServiceProvider = Provider<BrokerCustodyService>((ref) {
  final dio = ref.watch(dioProvider);
  return BrokerCustodyService(dio);
});

class BrokerCustodyService {
  final Dio _dio;

  BrokerCustodyService(this._dio);

  Future<List<BrokerCustodyAdvanceModel>> listAdvances({
    int? importFileId,
    int? brokerId,
    String? status,
    String? search,
  }) async {
    final query = <String, dynamic>{};
    if (importFileId != null) query['import_file_id'] = importFileId;
    if (brokerId != null) query['broker_id'] = brokerId;
    if (status != null && status != 'All') query['status'] = status;
    if (search != null && search.isNotEmpty) query['search'] = search;

    final response = await _dio.get('/api/v1/broker-custody/advances', queryParameters: query);
    final data = response.data['items'] as List;
    return data.map((e) => BrokerCustodyAdvanceModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BrokerCustodyAdvanceModel> getAdvance(int advanceId) async {
    final response = await _dio.get('/api/v1/broker-custody/advances/$advanceId');
    return BrokerCustodyAdvanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BrokerCustodyAdvanceModel> createAdvance({
    required int importFileId,
    required int brokerId,
    required String brokerName,
    required double advanceAmount,
    required String disbursementDate,
    String paymentMethod = 'BANK_TRANSFER',
    String? notes,
  }) async {
    final payload = {
      'import_file_id': importFileId,
      'broker_id': brokerId,
      'broker_name': brokerName,
      'advance_amount': advanceAmount,
      'disbursement_date': disbursementDate,
      'payment_method': paymentMethod,
      if (notes != null) 'notes': notes,
    };
    final response = await _dio.post('/api/v1/broker-custody/advances', data: payload);
    return BrokerCustodyAdvanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BrokerExpenseItemModel> addExpenseItem(
    int advanceId, {
    required String expenseCategory,
    required double amount,
    bool isEInvoiceBacked = false,
    String? eInvoiceUuid,
    String? receiptReference,
    double taxWithholdingRate = 0.01,
    String? notes,
  }) async {
    final payload = {
      'expense_category': expenseCategory,
      'amount': amount,
      'is_e_invoice_backed': isEInvoiceBacked,
      if (eInvoiceUuid != null) 'e_invoice_uuid': eInvoiceUuid,
      if (receiptReference != null) 'receipt_reference': receiptReference,
      'tax_withholding_rate': taxWithholdingRate,
      if (notes != null) 'notes': notes,
    };
    final response = await _dio.post(
      '/api/v1/broker-custody/advances/$advanceId/expenses',
      data: payload,
    );
    return BrokerExpenseItemModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BrokerExpenseItemModel> approveExpenseItem(
    int itemId, {
    required String approvalStatus,
    String? verifiedBy,
    String? notes,
  }) async {
    final payload = {
      'approval_status': approvalStatus,
      if (verifiedBy != null) 'verified_by': verifiedBy,
      if (notes != null) 'notes': notes,
    };
    final response = await _dio.post(
      '/api/v1/broker-custody/expenses/$itemId/approve',
      data: payload,
    );
    return BrokerExpenseItemModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SettlementReconciliationModel> settleAdvance(int advanceId) async {
    final response = await _dio.post('/api/v1/broker-custody/advances/$advanceId/settle');
    return SettlementReconciliationModel.fromJson(response.data as Map<String, dynamic>);
  }
}
