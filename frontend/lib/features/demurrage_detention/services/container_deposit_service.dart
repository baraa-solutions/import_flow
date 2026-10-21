import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/container_deposit_model.dart';

final containerDepositServiceProvider = Provider<ContainerDepositService>((ref) {
  final dio = ref.watch(dioProvider);
  return ContainerDepositService(dio);
});

class ContainerDepositService {
  final Dio _dio;

  ContainerDepositService(this._dio);

  Future<List<ContainerDepositModel>> listDeposits({
    int? importFileId,
    String? carrierName,
    String? refundStatus,
    String? containerNumber,
    bool includeInactive = false,
  }) async {
    final query = <String, dynamic>{
      'include_inactive': includeInactive,
    };
    if (importFileId != null) query['import_file_id'] = importFileId;
    if (carrierName != null && carrierName.isNotEmpty) query['carrier_name'] = carrierName;
    if (refundStatus != null && refundStatus != 'All') query['refund_status'] = refundStatus;
    if (containerNumber != null && containerNumber.isNotEmpty) query['container_number'] = containerNumber;

    final response = await _dio.get('/api/v1/container-deposit', queryParameters: query);
    final data = response.data['items'] as List;
    return data.map((e) => ContainerDepositModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ContainerDepositOverviewModel> getOverviewAndAlerts() async {
    final response = await _dio.get('/api/v1/container-deposit/alerts/overdue');
    return ContainerDepositOverviewModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ContainerDepositModel> getDeposit(int depositId) async {
    final response = await _dio.get('/api/v1/container-deposit/$depositId');
    return ContainerDepositModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ContainerDepositModel> createDeposit({
    required int importFileId,
    int? carrierId,
    required String carrierName,
    required String containerNumber,
    required String containerType,
    required double depositAmountEgp,
    String? paymentReference,
    required String paymentDate,
    String? notes,
  }) async {
    final payload = {
      'import_file_id': importFileId,
      if (carrierId != null) 'carrier_id': carrierId,
      'carrier_name': carrierName,
      'container_number': containerNumber,
      'container_type': containerType,
      'deposit_amount_egp': depositAmountEgp,
      if (paymentReference != null) 'payment_reference': paymentReference,
      'payment_date': paymentDate,
      if (notes != null) 'notes': notes,
    };
    final response = await _dio.post('/api/v1/container-deposit', data: payload);
    return ContainerDepositModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ContainerDepositModel> recordEirReturn(
    int depositId, {
    required String eirReturnNumber,
    required String eirReturnDate,
    String containerCondition = 'SOUND_CLEAN',
    double deductionAmountEgp = 0.0,
    String? deductionReason,
  }) async {
    final payload = {
      'eir_return_number': eirReturnNumber,
      'eir_return_date': eirReturnDate,
      'container_condition': containerCondition,
      'deduction_amount_egp': deductionAmountEgp,
      if (deductionReason != null) 'deduction_reason': deductionReason,
    };
    final response = await _dio.post('/api/v1/container-deposit/$depositId/record-eir', data: payload);
    return ContainerDepositModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ContainerDepositModel> recordRefund(
    int depositId, {
    required String refundChequeOrTransferNo,
    required String refundReceivedDate,
    required double refundAmountEgp,
  }) async {
    final payload = {
      'refund_cheque_or_transfer_no': refundChequeOrTransferNo,
      'refund_received_date': refundReceivedDate,
      'refund_amount_egp': refundAmountEgp,
    };
    final response = await _dio.post('/api/v1/container-deposit/$depositId/record-refund', data: payload);
    return ContainerDepositModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ContainerDepositModel> disputeDeduction(
    int depositId, {
    required String disputeReason,
    double? revisedDeductionAmountEgp,
    bool waived = false,
  }) async {
    final payload = {
      'dispute_reason': disputeReason,
      if (revisedDeductionAmountEgp != null) 'revised_deduction_amount_egp': revisedDeductionAmountEgp,
      'waived': waived,
    };
    final response = await _dio.post('/api/v1/container-deposit/$depositId/dispute-deduction', data: payload);
    return ContainerDepositModel.fromJson(response.data as Map<String, dynamic>);
  }
}
