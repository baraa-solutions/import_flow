import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/logistics_invoice_models.dart';

final logisticsInvoicesRepositoryProvider = Provider<LogisticsInvoicesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return LogisticsInvoicesRepository(dio);
});

class LogisticsInvoicesRepository {
  final Dio _dio;

  LogisticsInvoicesRepository(this._dio);

  // ── Invoices ───────────────────────────────────────────────────────────────

  Future<List<LogisticsInvoiceModel>> fetchInvoices({
    int? shipmentId,
    int? partnerId,
    String? partnerType,
    String? status,
    String? paymentStatus,
  }) async {
    final queryParams = <String, dynamic>{};
    if (shipmentId != null) queryParams['shipment_id'] = shipmentId;
    if (partnerId != null) queryParams['partner_id'] = partnerId;
    if (partnerType != null && partnerType.isNotEmpty && partnerType != 'all') {
      queryParams['partner_type'] = partnerType;
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      queryParams['status'] = status;
    }
    if (paymentStatus != null && paymentStatus.isNotEmpty && paymentStatus != 'all') {
      queryParams['payment_status'] = paymentStatus;
    }

    final res = await _dio.get('/api/v1/logistics-invoices', queryParameters: queryParams);
    return (res.data as List<dynamic>)
        .map((e) => LogisticsInvoiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LogisticsInvoiceModel> fetchInvoice(int id) async {
    final res = await _dio.get('/api/v1/logistics-invoices/$id');
    return LogisticsInvoiceModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LogisticsInvoiceModel> createInvoice(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/v1/logistics-invoices', data: data);
    return LogisticsInvoiceModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LogisticsInvoiceModel> updateInvoice(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/v1/logistics-invoices/$id', data: data);
    return LogisticsInvoiceModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LogisticsInvoiceModel> submitInvoice(int id) async {
    final res = await _dio.post('/api/v1/logistics-invoices/$id/submit');
    return LogisticsInvoiceModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LogisticsInvoiceModel> approveInvoice(int id) async {
    final res = await _dio.post('/api/v1/logistics-invoices/$id/approve');
    return LogisticsInvoiceModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LogisticsInvoiceModel> cancelInvoice(int id) async {
    final res = await _dio.post('/api/v1/logistics-invoices/$id/cancel');
    return LogisticsInvoiceModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PrefillLinesModel> getPrefillLines(int shipmentId, String partnerType) async {
    final res = await _dio.get(
      '/api/v1/logistics-invoices/prefill-lines',
      queryParameters: {
        'shipment_id': shipmentId,
        'partner_type': partnerType,
      },
    );
    return PrefillLinesModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ContainerLockStatusModel> getContainerLockStatus(int shipmentId, String blNumber) async {
    final res = await _dio.get(
      '/api/v1/logistics-invoices/container-lock-status',
      queryParameters: {
        'shipment_id': shipmentId,
        'bl_number': blNumber,
      },
    );
    return ContainerLockStatusModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<double> getCbeExchangeRate(String currency, [String? targetDate]) async {
    final queryParams = {'currency': currency};
    if (targetDate != null) queryParams['target_date'] = targetDate;
    final res = await _dio.get(
      '/api/v1/logistics-invoices/exchange-rate/cbe',
      queryParameters: queryParams,
    );
    return (res.data['rate'] as num?)?.toDouble() ?? 1.0;
  }

  Future<PartnerBalanceCardModel> getPartnerBalanceCard(int partnerId) async {
    final res = await _dio.get('/api/v1/logistics-invoices/partners/$partnerId/balance-card');
    return PartnerBalanceCardModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<LogisticsInvoiceModel>> getPartnerOpenInvoices(int partnerId) async {
    final res = await _dio.get('/api/v1/logistics-invoices/partners/$partnerId/open-invoices');
    return (res.data as List<dynamic>)
        .map((e) => LogisticsInvoiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ThreeWayMatchModel> getThreeWayMatch(int invoiceId) async {
    final res = await _dio.get('/api/v1/logistics-invoices/$invoiceId/three-way-match');
    return ThreeWayMatchModel.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Marine Insurance Policies ──────────────────────────────────────────────

  Future<List<InsurancePolicyModel>> fetchInsurancePolicies({
    int? shipmentId,
    int? insuranceCompanyId,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{};
    if (shipmentId != null) queryParams['shipment_id'] = shipmentId;
    if (insuranceCompanyId != null) queryParams['insurance_company_id'] = insuranceCompanyId;
    if (status != null && status.isNotEmpty && status != 'all') {
      queryParams['status'] = status;
    }

    final res = await _dio.get('/api/v1/logistics-invoices/insurance/policies', queryParameters: queryParams);
    return (res.data as List<dynamic>)
        .map((e) => InsurancePolicyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InsurancePreviewModel> getInsurancePreview(
    int shipmentId, {
    double premiumRate = 0.35,
    String coverageType = 'all_risks',
  }) async {
    final res = await _dio.get(
      '/api/v1/logistics-invoices/insurance/preview',
      queryParameters: {
        'shipment_id': shipmentId,
        'premium_rate': premiumRate,
        'coverage_type': coverageType,
      },
    );
    return InsurancePreviewModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<InsurancePolicyModel> createInsurancePolicy(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/v1/logistics-invoices/insurance/policies', data: data);
    return InsurancePolicyModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LogisticsInvoiceModel> generateInvoiceFromPolicy(int policyId) async {
    final res = await _dio.post('/api/v1/logistics-invoices/insurance/policies/$policyId/generate-invoice');
    return LogisticsInvoiceModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<InsurancePolicyModel> recordInsuranceClaim(int policyId, Map<String, dynamic> data) async {
    final res = await _dio.post('/api/v1/logistics-invoices/insurance/policies/$policyId/claim', data: data);
    return InsurancePolicyModel.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Clearance Advance Payments ─────────────────────────────────────────────

  Future<List<ClearanceAdvancePaymentModel>> fetchClearanceAdvances({
    int? shipmentId,
    int? partnerId,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{};
    if (shipmentId != null) queryParams['shipment_id'] = shipmentId;
    if (partnerId != null) queryParams['partner_id'] = partnerId;
    if (status != null && status.isNotEmpty && status != 'all') {
      queryParams['status'] = status;
    }

    final res = await _dio.get('/api/v1/logistics-invoices/advances', queryParameters: queryParams);
    return (res.data as List<dynamic>)
        .map((e) => ClearanceAdvancePaymentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClearanceAdvancePaymentModel> createClearanceAdvance(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/v1/logistics-invoices/advances', data: data);
    return ClearanceAdvancePaymentModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ClearanceAdvanceSettlementModel> settleClearanceAdvance(int advanceId, Map<String, dynamic> data) async {
    final res = await _dio.post('/api/v1/logistics-invoices/advances/$advanceId/settle', data: data);
    return ClearanceAdvanceSettlementModel.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Payment Vouchers & Knock-Offs ──────────────────────────────────────────

  Future<List<LogisticsPaymentVoucherModel>> fetchPaymentVouchers({
    int? partnerId,
    int? shipmentId,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{};
    if (partnerId != null) queryParams['partner_id'] = partnerId;
    if (shipmentId != null) queryParams['shipment_id'] = shipmentId;
    if (status != null && status.isNotEmpty && status != 'all') {
      queryParams['status'] = status;
    }

    final res = await _dio.get('/api/v1/logistics-invoices/payments', queryParameters: queryParams);
    return (res.data as List<dynamic>)
        .map((e) => LogisticsPaymentVoucherModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LogisticsPaymentVoucherModel> createPaymentVoucher(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/v1/logistics-invoices/payments', data: data);
    return LogisticsPaymentVoucherModel.fromJson(res.data as Map<String, dynamic>);
  }
}
