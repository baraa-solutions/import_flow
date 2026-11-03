import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

class LegalClaimItem {
  final int id;
  final String claimCode;
  final int importFileId;
  final int? shipmentId;
  final String claimType;
  final String damageNature;
  final DateTime? deliveryDate;
  final DateTime? latentNoticeDeadline;
  final DateTime? apparentNoticeDate;
  final DateTime timeBarStatuteOfLimitationsDate;
  final String status;
  final String? reservationLetterRef;
  final DateTime? reservationLetterDate;
  final String targetParty;
  final bool surveyRequested;
  final DateTime? surveyDate;
  final String? surveyorCompany;
  final String? surveyReportRef;
  final double claimedAmount;
  final String claimedCurrency;
  final double settledAmount;
  final DateTime? settlementDate;
  final String? notes;
  final int daysUntilTimeBar;
  final int? daysUntilLatentDeadline;
  final bool isLatentNoticeExpired;
  final bool isTimeBarred;
  final String urgencyLevel;

  const LegalClaimItem({
    required this.id,
    required this.claimCode,
    required this.importFileId,
    this.shipmentId,
    required this.claimType,
    required this.damageNature,
    this.deliveryDate,
    this.latentNoticeDeadline,
    this.apparentNoticeDate,
    required this.timeBarStatuteOfLimitationsDate,
    required this.status,
    this.reservationLetterRef,
    this.reservationLetterDate,
    required this.targetParty,
    required this.surveyRequested,
    this.surveyDate,
    this.surveyorCompany,
    this.surveyReportRef,
    required this.claimedAmount,
    required this.claimedCurrency,
    required this.settledAmount,
    this.settlementDate,
    this.notes,
    required this.daysUntilTimeBar,
    this.daysUntilLatentDeadline,
    required this.isLatentNoticeExpired,
    required this.isTimeBarred,
    required this.urgencyLevel,
  });

  factory LegalClaimItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v != null ? DateTime.tryParse(v.toString()) : null;

    return LegalClaimItem(
      id: json['id'] as int,
      claimCode: json['claim_code'] as String? ?? '',
      importFileId: json['import_file_id'] as int? ?? 0,
      shipmentId: json['shipment_id'] as int?,
      claimType: json['claim_type'] as String? ?? 'CARRIER_DAMAGE',
      damageNature: json['damage_nature'] as String? ?? 'APPARENT',
      deliveryDate: parseDate(json['delivery_date']),
      latentNoticeDeadline: parseDate(json['latent_notice_deadline']),
      apparentNoticeDate: parseDate(json['apparent_notice_date']),
      timeBarStatuteOfLimitationsDate: parseDate(json['time_bar_statute_of_limitations_date']) ?? DateTime.now(),
      status: json['status'] as String? ?? 'RESERVATION_ISSUED',
      reservationLetterRef: json['reservation_letter_ref'] as String?,
      reservationLetterDate: parseDate(json['reservation_letter_date']),
      targetParty: json['target_party'] as String? ?? '',
      surveyRequested: json['survey_requested'] as bool? ?? false,
      surveyDate: parseDate(json['survey_date']),
      surveyorCompany: json['surveyor_company'] as String?,
      surveyReportRef: json['survey_report_ref'] as String?,
      claimedAmount: (json['claimed_amount'] as num?)?.toDouble() ?? 0.0,
      claimedCurrency: json['claimed_currency'] as String? ?? 'USD',
      settledAmount: (json['settled_amount'] as num?)?.toDouble() ?? 0.0,
      settlementDate: parseDate(json['settlement_date']),
      notes: json['notes'] as String?,
      daysUntilTimeBar: json['days_until_time_bar'] as int? ?? 0,
      daysUntilLatentDeadline: json['days_until_latent_deadline'] as int?,
      isLatentNoticeExpired: json['is_latent_notice_expired'] as bool? ?? false,
      isTimeBarred: json['is_time_barred'] as bool? ?? false,
      urgencyLevel: json['urgency_level'] as String? ?? 'NORMAL',
    );
  }
}

class LegalClaimsState {
  final List<LegalClaimItem> items;
  final bool isLoading;
  final String? errorMessage;
  final int? selectedFileId;
  final String? selectedClaimType;

  const LegalClaimsState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedFileId,
    this.selectedClaimType,
  });

  LegalClaimsState copyWith({
    List<LegalClaimItem>? items,
    bool? isLoading,
    String? errorMessage,
    int? selectedFileId,
    String? selectedClaimType,
  }) {
    return LegalClaimsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedFileId: selectedFileId ?? this.selectedFileId,
      selectedClaimType: selectedClaimType ?? this.selectedClaimType,
    );
  }
}

class LegalClaimsNotifier extends StateNotifier<LegalClaimsState> {
  final Dio _dio;

  LegalClaimsNotifier(this._dio) : super(const LegalClaimsState());

  Future<void> fetchClaims({int? fileId, String? claimType}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final qParams = <String, dynamic>{'size': 100};
      if (fileId != null) qParams['import_file_id'] = fileId;
      if (claimType != null) qParams['claim_type'] = claimType;

      final res = await _dio.get('/api/v1/legal-claims', queryParameters: qParams);
      final data = res.data;
      final rawList = data is Map<String, dynamic> ? data['items'] as List? ?? [] : [];
      final list = rawList
          .map((e) => LegalClaimItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        items: list,
        isLoading: false,
        selectedFileId: fileId,
        selectedClaimType: claimType,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createClaim(Map<String, dynamic> payload) async {
    try {
      await _dio.post('/api/v1/legal-claims', data: payload);
      await fetchClaims(fileId: state.selectedFileId, claimType: state.selectedClaimType);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> scheduleSurvey(int id, Map<String, dynamic> payload) async {
    try {
      await _dio.post('/api/v1/legal-claims/$id/schedule-survey', data: payload);
      await fetchClaims(fileId: state.selectedFileId, claimType: state.selectedClaimType);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> settleClaim(int id, Map<String, dynamic> payload) async {
    try {
      await _dio.post('/api/v1/legal-claims/$id/settle', data: payload);
      await fetchClaims(fileId: state.selectedFileId, claimType: state.selectedClaimType);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteClaim(int id) async {
    try {
      await _dio.delete('/api/v1/legal-claims/$id');
      await fetchClaims(fileId: state.selectedFileId, claimType: state.selectedClaimType);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final legalClaimsProvider =
    StateNotifierProvider<LegalClaimsNotifier, LegalClaimsState>((ref) {
  final dio = ref.watch(dioProvider);
  return LegalClaimsNotifier(dio);
});
