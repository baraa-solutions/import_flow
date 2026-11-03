import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

class TradeAgreementItem {
  final int id;
  final String verificationCode;
  final int importFileId;
  final int? shipmentId;
  final String agreementName;
  final String certificateType;
  final String certificateNumber;
  final String issuingCountry;
  final String? issuingAuthority;
  final DateTime issuingDate;
  final int validityMonths;
  final DateTime? expiryDate;
  final String submissionStatus;
  final bool hasOriginalReceived;
  final DateTime? originalReceivedDate;
  final bool provisionalEscrowRequired;
  final double provisionalEscrowAmount;
  final String? provisionalEscrowReceipt;
  final DateTime? provisionalEscrowDeadline;
  final bool provisionalEscrowRefunded;
  final DateTime? refundDate;
  final bool directTransportCompliant;
  final String? rulesOfOriginCriterion;
  final String? verificationNotes;
  final int? daysUntilExpiry;
  final int? daysUntilEscrowDeadline;
  final bool isCertExpired;
  final bool isEscrowAtRisk;

  const TradeAgreementItem({
    required this.id,
    required this.verificationCode,
    required this.importFileId,
    this.shipmentId,
    required this.agreementName,
    required this.certificateType,
    required this.certificateNumber,
    required this.issuingCountry,
    this.issuingAuthority,
    required this.issuingDate,
    required this.validityMonths,
    this.expiryDate,
    required this.submissionStatus,
    required this.hasOriginalReceived,
    this.originalReceivedDate,
    required this.provisionalEscrowRequired,
    required this.provisionalEscrowAmount,
    this.provisionalEscrowReceipt,
    this.provisionalEscrowDeadline,
    required this.provisionalEscrowRefunded,
    this.refundDate,
    required this.directTransportCompliant,
    this.rulesOfOriginCriterion,
    this.verificationNotes,
    this.daysUntilExpiry,
    this.daysUntilEscrowDeadline,
    required this.isCertExpired,
    required this.isEscrowAtRisk,
  });

  factory TradeAgreementItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v != null ? DateTime.tryParse(v.toString()) : null;

    return TradeAgreementItem(
      id: json['id'] as int,
      verificationCode: json['verification_code'] as String? ?? '',
      importFileId: json['import_file_id'] as int? ?? 0,
      shipmentId: json['shipment_id'] as int?,
      agreementName: json['agreement_name'] as String? ?? 'EUR1',
      certificateType: json['certificate_type'] as String? ?? 'EUR.1',
      certificateNumber: json['certificate_number'] as String? ?? '',
      issuingCountry: json['issuing_country'] as String? ?? '',
      issuingAuthority: json['issuing_authority'] as String?,
      issuingDate: parseDate(json['issuing_date']) ?? DateTime.now(),
      validityMonths: json['validity_months'] as int? ?? 4,
      expiryDate: parseDate(json['expiry_date']),
      submissionStatus: json['submission_status'] as String? ?? 'COPY_SUBMITTED',
      hasOriginalReceived: json['has_original_received'] as bool? ?? false,
      originalReceivedDate: parseDate(json['original_received_date']),
      provisionalEscrowRequired: json['provisional_escrow_required'] as bool? ?? false,
      provisionalEscrowAmount: (json['provisional_escrow_amount'] as num?)?.toDouble() ?? 0.0,
      provisionalEscrowReceipt: json['provisional_escrow_receipt'] as String?,
      provisionalEscrowDeadline: parseDate(json['provisional_escrow_deadline']),
      provisionalEscrowRefunded: json['provisional_escrow_refunded'] as bool? ?? false,
      refundDate: parseDate(json['refund_date']),
      directTransportCompliant: json['direct_transport_compliant'] as bool? ?? true,
      rulesOfOriginCriterion: json['rules_of_origin_criterion'] as String?,
      verificationNotes: json['verification_notes'] as String?,
      daysUntilExpiry: json['days_until_expiry'] as int?,
      daysUntilEscrowDeadline: json['days_until_escrow_deadline'] as int?,
      isCertExpired: json['is_cert_expired'] as bool? ?? false,
      isEscrowAtRisk: json['is_escrow_at_risk'] as bool? ?? false,
    );
  }
}

class TradeAgreementsState {
  final List<TradeAgreementItem> items;
  final bool isLoading;
  final String? errorMessage;
  final int? selectedFileId;
  final String? selectedAgreement;

  const TradeAgreementsState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedFileId,
    this.selectedAgreement,
  });

  TradeAgreementsState copyWith({
    List<TradeAgreementItem>? items,
    bool? isLoading,
    String? errorMessage,
    int? selectedFileId,
    String? selectedAgreement,
  }) {
    return TradeAgreementsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedFileId: selectedFileId ?? this.selectedFileId,
      selectedAgreement: selectedAgreement ?? this.selectedAgreement,
    );
  }
}

class TradeAgreementsNotifier extends StateNotifier<TradeAgreementsState> {
  final Dio _dio;

  TradeAgreementsNotifier(this._dio) : super(const TradeAgreementsState());

  Future<void> fetchVerifications({int? fileId, String? agreementName}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final qParams = <String, dynamic>{'size': 100};
      if (fileId != null) qParams['import_file_id'] = fileId;
      if (agreementName != null) qParams['agreement_name'] = agreementName;

      final res = await _dio.get('/api/v1/trade-agreements', queryParameters: qParams);
      final data = res.data;
      final rawList = data is Map<String, dynamic> ? data['items'] as List? ?? [] : [];
      final list = rawList
          .map((e) => TradeAgreementItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        items: list,
        isLoading: false,
        selectedFileId: fileId,
        selectedAgreement: agreementName,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createVerification(Map<String, dynamic> payload) async {
    try {
      await _dio.post('/api/v1/trade-agreements', data: payload);
      await fetchVerifications(fileId: state.selectedFileId, agreementName: state.selectedAgreement);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> verifyOriginal(int id, Map<String, dynamic> payload) async {
    try {
      await _dio.post('/api/v1/trade-agreements/$id/verify-original', data: payload);
      await fetchVerifications(fileId: state.selectedFileId, agreementName: state.selectedAgreement);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteVerification(int id) async {
    try {
      await _dio.delete('/api/v1/trade-agreements/$id');
      await fetchVerifications(fileId: state.selectedFileId, agreementName: state.selectedAgreement);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final tradeAgreementsProvider =
    StateNotifierProvider<TradeAgreementsNotifier, TradeAgreementsState>((ref) {
  final dio = ref.watch(dioProvider);
  return TradeAgreementsNotifier(dio);
});
