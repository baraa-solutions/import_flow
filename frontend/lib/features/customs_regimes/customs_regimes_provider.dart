import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

class CustomsRegimeItem {
  final int id;
  final String regimeCode;
  final int importFileId;
  final int? shipmentId;
  final String regimeType;
  final String status;
  final String? customsOffice;
  final String? releaseFormNumber;
  final DateTime? releaseDate;
  final String? guaranteeType;
  final String? guaranteeReference;
  final String? guaranteeBank;
  final double guaranteeAmount;
  final String guaranteeCurrency;
  final DateTime? guaranteeIssueDate;
  final DateTime? guaranteeExpiryDate;
  final DateTime? reExportDeadline;
  final DateTime? actualReExportDate;
  final String? reExportExportDeclarationNo;
  final String? drawbackReconciliationRef;
  final double drawbackRefundAmount;
  final DateTime? reconciledDate;
  final bool isSettled;
  final String? notes;
  final int? daysUntilReExport;
  final bool isExpired;
  final bool guaranteeActive;

  const CustomsRegimeItem({
    required this.id,
    required this.regimeCode,
    required this.importFileId,
    this.shipmentId,
    required this.regimeType,
    required this.status,
    this.customsOffice,
    this.releaseFormNumber,
    this.releaseDate,
    this.guaranteeType,
    this.guaranteeReference,
    this.guaranteeBank,
    required this.guaranteeAmount,
    required this.guaranteeCurrency,
    this.guaranteeIssueDate,
    this.guaranteeExpiryDate,
    this.reExportDeadline,
    this.actualReExportDate,
    this.reExportExportDeclarationNo,
    this.drawbackReconciliationRef,
    required this.drawbackRefundAmount,
    this.reconciledDate,
    required this.isSettled,
    this.notes,
    this.daysUntilReExport,
    required this.isExpired,
    required this.guaranteeActive,
  });

  factory CustomsRegimeItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v != null ? DateTime.tryParse(v.toString()) : null;

    return CustomsRegimeItem(
      id: json['id'] as int,
      regimeCode: json['regime_code'] as String? ?? '',
      importFileId: json['import_file_id'] as int? ?? 0,
      shipmentId: json['shipment_id'] as int?,
      regimeType: json['regime_type'] as String? ?? 'TEMPORARY_ADMISSION',
      status: json['status'] as String? ?? 'ACTIVE',
      customsOffice: json['customs_office'] as String?,
      releaseFormNumber: json['release_form_number'] as String?,
      releaseDate: parseDate(json['release_date']),
      guaranteeType: json['guarantee_type'] as String?,
      guaranteeReference: json['guarantee_reference'] as String?,
      guaranteeBank: json['guarantee_bank'] as String?,
      guaranteeAmount: (json['guarantee_amount'] as num?)?.toDouble() ?? 0.0,
      guaranteeCurrency: json['guarantee_currency'] as String? ?? 'EGP',
      guaranteeIssueDate: parseDate(json['guarantee_issue_date']),
      guaranteeExpiryDate: parseDate(json['guarantee_expiry_date']),
      reExportDeadline: parseDate(json['re_export_deadline']),
      actualReExportDate: parseDate(json['actual_re_export_date']),
      reExportExportDeclarationNo: json['re_export_export_declaration_no'] as String?,
      drawbackReconciliationRef: json['drawback_reconciliation_ref'] as String?,
      drawbackRefundAmount: (json['drawback_refund_amount'] as num?)?.toDouble() ?? 0.0,
      reconciledDate: parseDate(json['reconciled_date']),
      isSettled: json['is_settled'] as bool? ?? false,
      notes: json['notes'] as String?,
      daysUntilReExport: json['days_until_re_export'] as int?,
      isExpired: json['is_expired'] as bool? ?? false,
      guaranteeActive: json['guarantee_active'] as bool? ?? false,
    );
  }
}

class CustomsRegimesState {
  final List<CustomsRegimeItem> items;
  final bool isLoading;
  final String? errorMessage;
  final int? selectedFileId;
  final String? selectedRegimeType;

  const CustomsRegimesState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedFileId,
    this.selectedRegimeType,
  });

  CustomsRegimesState copyWith({
    List<CustomsRegimeItem>? items,
    bool? isLoading,
    String? errorMessage,
    int? selectedFileId,
    String? selectedRegimeType,
  }) {
    return CustomsRegimesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedFileId: selectedFileId ?? this.selectedFileId,
      selectedRegimeType: selectedRegimeType ?? this.selectedRegimeType,
    );
  }
}

class CustomsRegimesNotifier extends StateNotifier<CustomsRegimesState> {
  final Dio _dio;

  CustomsRegimesNotifier(this._dio) : super(const CustomsRegimesState());

  Future<void> fetchRegimes({int? fileId, String? regimeType}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final qParams = <String, dynamic>{'size': 100};
      if (fileId != null) qParams['import_file_id'] = fileId;
      if (regimeType != null) qParams['regime_type'] = regimeType;

      final res = await _dio.get('/api/v1/customs-regimes', queryParameters: qParams);
      final data = res.data;
      final rawList = data is Map<String, dynamic> ? data['items'] as List? ?? [] : [];
      final list = rawList
          .map((e) => CustomsRegimeItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        items: list,
        isLoading: false,
        selectedFileId: fileId,
        selectedRegimeType: regimeType,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createRegime(Map<String, dynamic> payload) async {
    try {
      await _dio.post('/api/v1/customs-regimes', data: payload);
      await fetchRegimes(fileId: state.selectedFileId, regimeType: state.selectedRegimeType);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> settleRegime(int regimeId, Map<String, dynamic> payload) async {
    try {
      await _dio.post('/api/v1/customs-regimes/$regimeId/settle', data: payload);
      await fetchRegimes(fileId: state.selectedFileId, regimeType: state.selectedRegimeType);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteRegime(int regimeId) async {
    try {
      await _dio.delete('/api/v1/customs-regimes/$regimeId');
      await fetchRegimes(fileId: state.selectedFileId, regimeType: state.selectedRegimeType);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final customsRegimesProvider =
    StateNotifierProvider<CustomsRegimesNotifier, CustomsRegimesState>((ref) {
  final dio = ref.watch(dioProvider);
  return CustomsRegimesNotifier(dio);
});
