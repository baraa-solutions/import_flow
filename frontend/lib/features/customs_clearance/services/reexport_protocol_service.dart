import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/reexport_protocol_model.dart';

final reexportProtocolServiceProvider = Provider<ReexportProtocolService>((ref) {
  final dio = ref.watch(dioProvider);
  return ReexportProtocolService(dio);
});

class ReexportProtocolService {
  final Dio _dio;

  ReexportProtocolService(this._dio);

  Future<List<ReexportDossierModel>> listDossiers({
    int? importFileId,
    String? status,
    String? search,
    bool includeInactive = false,
  }) async {
    final query = <String, dynamic>{
      'include_inactive': includeInactive,
    };
    if (importFileId != null) query['import_file_id'] = importFileId;
    if (status != null && status != 'All') query['status'] = status;
    if (search != null && search.isNotEmpty) query['search'] = search;

    final response = await _dio.get('/api/v1/reexport-protocol', queryParameters: query);
    final data = response.data['items'] as List;
    return data.map((e) => ReexportDossierModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DestructionAlertOverviewModel> getDestructionAlerts() async {
    final response = await _dio.get('/api/v1/reexport-protocol/alerts/destruction-countdown');
    return DestructionAlertOverviewModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReexportDossierModel> getDossier(int reexportId) async {
    final response = await _dio.get('/api/v1/reexport-protocol/$reexportId');
    return ReexportDossierModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReexportDossierModel> createDossier({
    required int importFileId,
    required String importFileCode,
    required String rejectionAuthority,
    required String rejectionDecreeNumber,
    required String rejectionDate,
    required String reexportReason,
    List<String> containerNumbers = const [],
    String? legalReexportDeadline,
    String? notes,
  }) async {
    final payload = {
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      'rejection_authority': rejectionAuthority,
      'rejection_decree_number': rejectionDecreeNumber,
      'rejection_date': rejectionDate,
      'reexport_reason': reexportReason,
      'container_numbers': containerNumbers,
      if (legalReexportDeadline != null) 'legal_reexport_deadline': legalReexportDeadline,
      if (notes != null) 'notes': notes,
    };
    final response = await _dio.post('/api/v1/reexport-protocol', data: payload);
    return ReexportDossierModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReexportDossierModel> recordOutboundBooking(
    int reexportId, {
    int? returnCarrierId,
    required String returnBookingNumber,
    required String returnPortOfDischarge,
    String? outboundBlNumber,
  }) async {
    final payload = {
      if (returnCarrierId != null) 'return_carrier_id': returnCarrierId,
      'return_booking_number': returnBookingNumber,
      'return_port_of_discharge': returnPortOfDischarge,
      if (outboundBlNumber != null) 'outbound_bl_number': outboundBlNumber,
    };
    final response = await _dio.post(
      '/api/v1/reexport-protocol/$reexportId/outbound-declaration',
      data: payload,
    );
    return ReexportDossierModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReexportDossierModel> formSupervisionCommittee(
    int reexportId, {
    required String customsOfficerInCharge,
    required String customsOutboundDeclarationNo,
  }) async {
    final payload = {
      'supervision_committee_formed': true,
      'customs_officer_in_charge': customsOfficerInCharge,
      'customs_outbound_declaration_no': customsOutboundDeclarationNo,
    };
    final response = await _dio.post(
      '/api/v1/reexport-protocol/$reexportId/supervision-committee',
      data: payload,
    );
    return ReexportDossierModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReexportDossierModel> recordCreditNote(
    int reexportId, {
    required String supplierCreditNoteStatus,
    required double creditNoteAmountUsd,
  }) async {
    final payload = {
      'supplier_credit_note_status': supplierCreditNoteStatus,
      'credit_note_amount_usd': creditNoteAmountUsd,
    };
    final response = await _dio.post(
      '/api/v1/reexport-protocol/$reexportId/credit-note',
      data: payload,
    );
    return ReexportDossierModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReexportDossierModel> recordDutyDrawback(
    int reexportId, {
    required String dutyDrawbackStatus,
    required double dutyAmountRefundableEgp,
  }) async {
    final payload = {
      'duty_drawback_status': dutyDrawbackStatus,
      'duty_amount_refundable_egp': dutyAmountRefundableEgp,
    };
    final response = await _dio.post(
      '/api/v1/reexport-protocol/$reexportId/duty-drawback',
      data: payload,
    );
    return ReexportDossierModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReexportDossierModel> transitionStatus(
    int reexportId,
    String nextStatus,
  ) async {
    final response = await _dio.patch(
      '/api/v1/reexport-protocol/$reexportId/status',
      data: {'status': nextStatus},
    );
    return ReexportDossierModel.fromJson(response.data as Map<String, dynamic>);
  }
}
