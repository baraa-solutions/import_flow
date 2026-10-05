import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../models/customs_consultation_model.dart';
import '../../../core/network/api_client.dart';


// ==============================================================================
// Clearance Expense Types Provider
// ==============================================================================

final clearanceExpenseTypesProvider =
    StateNotifierProvider<ClearanceExpenseTypesNotifier, AsyncValue<List<ClearanceExpenseTypeModel>>>((ref) {
  return ClearanceExpenseTypesNotifier(ref.read(dioProvider));
});

class ClearanceExpenseTypesNotifier extends StateNotifier<AsyncValue<List<ClearanceExpenseTypeModel>>> {
  final Dio _dio;
  CancelToken? _cancelToken;

  ClearanceExpenseTypesNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetchExpenseTypes();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('ClearanceExpenseTypesNotifier disposed');
    super.dispose();
  }

  Future<void> fetchExpenseTypes({
    bool includeInactive = false,
    String? category,
    String? search,
  }) async {
    _cancelToken?.cancel('New fetch requested');
    _cancelToken = CancelToken();
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{
        'include_inactive': includeInactive,
      };
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/customs-consultations/expense-types',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List<dynamic> data = response.data;
      final items = data.map((json) => ClearanceExpenseTypeModel.fromJson(json)).toList();
      state = AsyncValue.data(items);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = AsyncValue.error(e, stack);
    }
  }

  Future<ClearanceExpenseTypeModel?> createExpenseType(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-consultations/expense-types',
        data: payload,
      );
      final item = ClearanceExpenseTypeModel.fromJson(response.data);
      await fetchExpenseTypes();
      return item;
    } catch (e) {
      rethrow;
    }
  }

  Future<ClearanceExpenseTypeModel?> updateExpenseType(int expenseId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.baseUrl}/customs-consultations/expense-types/$expenseId',
        data: payload,
      );
      final item = ClearanceExpenseTypeModel.fromJson(response.data);
      await fetchExpenseTypes();
      return item;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteExpenseType(int expenseId) async {
    try {
      await _dio.delete('${ApiConstants.baseUrl}/customs-consultations/expense-types/$expenseId');
      await fetchExpenseTypes();
    } catch (e) {
      rethrow;
    }
  }
}

// ==============================================================================
// Broker Price Lists Provider
// ==============================================================================

final brokerPriceListsProvider =
    StateNotifierProvider<BrokerPriceListsNotifier, AsyncValue<List<BrokerPriceListModel>>>((ref) {
  return BrokerPriceListsNotifier(ref.read(dioProvider));
});

class BrokerPriceListsNotifier extends StateNotifier<AsyncValue<List<BrokerPriceListModel>>> {
  final Dio _dio;
  CancelToken? _cancelToken;

  BrokerPriceListsNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetchPriceLists();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('BrokerPriceListsNotifier disposed');
    super.dispose();
  }

  Future<void> fetchPriceLists({
    bool includeInactive = false,
    int? brokerId,
    String? search,
  }) async {
    _cancelToken?.cancel('New fetch requested');
    _cancelToken = CancelToken();
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{
        'include_inactive': includeInactive,
      };
      if (brokerId != null) queryParams['broker_id'] = brokerId;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/customs-consultations/price-lists',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List<dynamic> data = response.data;
      final items = data.map((json) => BrokerPriceListModel.fromJson(json)).toList();
      state = AsyncValue.data(items);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      state = AsyncValue.error(e, stack);
    }
  }

  Future<BrokerPriceListModel?> getActivePriceListForBroker(int brokerId, {String? targetDate}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (targetDate != null) queryParams['target_date'] = targetDate;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/customs-consultations/price-lists/active/$brokerId',
        queryParameters: queryParams,
      );
      if (response.data == null) return null;
      return BrokerPriceListModel.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<BrokerPriceListModel?> createPriceList(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-consultations/price-lists',
        data: payload,
      );
      final pl = BrokerPriceListModel.fromJson(response.data);
      await fetchPriceLists();
      return pl;
    } catch (e) {
      rethrow;
    }
  }

  Future<BrokerPriceListModel?> updatePriceList(int priceListId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.baseUrl}/customs-consultations/price-lists/$priceListId',
        data: payload,
      );
      final pl = BrokerPriceListModel.fromJson(response.data);
      await fetchPriceLists();
      return pl;
    } catch (e) {
      rethrow;
    }
  }

  Future<BrokerPriceListModel?> clonePriceList(int priceListId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-consultations/price-lists/$priceListId/clone',
        data: payload,
      );
      final pl = BrokerPriceListModel.fromJson(response.data);
      await fetchPriceLists();
      return pl;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> softDeletePriceList(int priceListId) async {
    try {
      await _dio.delete('${ApiConstants.baseUrl}/customs-consultations/price-lists/$priceListId');
      await fetchPriceLists();
    } catch (e) {
      rethrow;
    }
  }
}

// ==============================================================================
// Customs Consultations Provider
// ==============================================================================

final customsConsultationsProvider =
    StateNotifierProvider<CustomsConsultationNotifier, AsyncValue<List<CustomsConsultationModel>>>((ref) {
  return CustomsConsultationNotifier(ref.read(dioProvider));
});

class CustomsConsultationNotifier extends StateNotifier<AsyncValue<List<CustomsConsultationModel>>> {
  final Dio _dio;
  CancelToken? _cancelToken;

  CustomsConsultationNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetchConsultations();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('CustomsConsultationNotifier disposed');
    super.dispose();
  }

  Future<void> fetchConsultations({
    bool includeInactive = false,
    String? search,
    int? brokerId,
    int? poId,
    int? projectId,
    String? status,
  }) async {
    _cancelToken?.cancel('New fetch requested');
    _cancelToken = CancelToken();
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{
        'include_inactive': includeInactive,
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (brokerId != null) queryParams['broker_id'] = brokerId;
      if (poId != null) queryParams['po_id'] = poId;
      if (projectId != null) queryParams['project_id'] = projectId;
      if (status != null && status.isNotEmpty && status != 'All') queryParams['status'] = status;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/customs-consultations',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );

      final List<dynamic> data = response.data;
      final consultations = data.map((json) => CustomsConsultationModel.fromJson(json)).toList();
      state = AsyncValue.data(consultations);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return; // Silent cancellation
      }
      state = AsyncValue.error(e, stack);
    }
  }

  Future<CustomsConsultationModel?> createConsultation(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-consultations',
        data: payload,
      );
      final newConsultation = CustomsConsultationModel.fromJson(response.data);
      await fetchConsultations();
      return newConsultation;
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsConsultationModel?> updateConsultation(int consultationId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.baseUrl}/customs-consultations/$consultationId',
        data: payload,
      );
      final updated = CustomsConsultationModel.fromJson(response.data);
      await fetchConsultations();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> softDeleteConsultation(int consultationId) async {
    try {
      await _dio.delete('${ApiConstants.baseUrl}/customs-consultations/$consultationId');
      await fetchConsultations();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> restoreConsultation(int consultationId) async {
    try {
      await _dio.post('${ApiConstants.baseUrl}/customs-consultations/$consultationId/restore');
      await fetchConsultations();
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsRecalculationResponseModel> recalculateFromReconciliation({
    required int importFileId,
    double? exchangeRate,
    double? preliminaryExchangeRate,
    double? freightEgp,
    double? insuranceEgp,
    String? estimateDate,
  }) async {
    try {
      final payload = <String, dynamic>{
        'import_file_id': importFileId,
        if (exchangeRate != null) 'exchange_rate': exchangeRate,
        if (preliminaryExchangeRate != null) 'preliminary_exchange_rate': preliminaryExchangeRate,
        if (freightEgp != null) 'freight_egp': freightEgp,
        if (insuranceEgp != null) 'insurance_egp': insuranceEgp,
        if (estimateDate != null) 'estimate_date': estimateDate,
      };
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-consultations/recalculate-from-reconciliation',
        data: payload,
      );
      return CustomsRecalculationResponseModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomsConsultationModel?> cloneConsultation(int consultationId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-consultations/$consultationId/clone',
        data: payload,
      );
      final item = CustomsConsultationModel.fromJson(response.data);
      await fetchConsultations();
      return item;
    } catch (e) {
      rethrow;
    }
  }
}

// ── Expense Catalog (AI-EXPENSE-CATALOG-002) ──────────────────────────────────

class ExpenseCatalogItemModel {
  final String code;
  final String canonicalNameAr;
  final String? canonicalNameEn;
  final String category;
  final String unitType;
  final bool allowComposite;
  final List<String> recognitionPatterns;
  final bool isActive;
  final String? createdAt;

  ExpenseCatalogItemModel({
    required this.code,
    required this.canonicalNameAr,
    this.canonicalNameEn,
    required this.category,
    required this.unitType,
    required this.allowComposite,
    required this.recognitionPatterns,
    required this.isActive,
    this.createdAt,
  });

  factory ExpenseCatalogItemModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCatalogItemModel(
      code: json['code']?.toString() ?? '',
      canonicalNameAr: json['canonical_name_ar']?.toString() ?? '',
      canonicalNameEn: json['canonical_name_en']?.toString(),
      category: json['category']?.toString() ?? '',
      unitType: json['unit_type']?.toString() ?? 'fixed',
      allowComposite: json['allow_composite'] == true,
      recognitionPatterns: (json['recognition_patterns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isActive: json['is_active'] != false,
      createdAt: json['created_at']?.toString(),
    );
  }
}

final expenseCatalogProvider =
    StateNotifierProvider<ExpenseCatalogNotifier, AsyncValue<List<ExpenseCatalogItemModel>>>((ref) {
  return ExpenseCatalogNotifier(ref.read(dioProvider));
});

class ExpenseCatalogNotifier extends StateNotifier<AsyncValue<List<ExpenseCatalogItemModel>>> {
  final Dio _dio;
  CancelToken? _cancelToken;

  ExpenseCatalogNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetchCatalog();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('ExpenseCatalogNotifier disposed');
    super.dispose();
  }

  Future<void> fetchCatalog({String? category, String? search}) async {
    _cancelToken?.cancel('New fetch requested');
    _cancelToken = CancelToken();
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{'active_only': true};
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = category;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      final response = await _dio.get(
        ApiConstants.expenseCatalog,
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );
      final List<dynamic> data = response.data;
      final items = data.map((j) => ExpenseCatalogItemModel.fromJson(j)).toList();
      state = AsyncValue.data(items);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      state = AsyncValue.error(e, stack);
    }
  }

  Future<ExpenseCatalogItemModel?> createItem(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post(
        ApiConstants.expenseCatalog,
        data: payload,
      );
      final item = ExpenseCatalogItemModel.fromJson(res.data);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([...current, item]);
      return item;
    } catch (e) {
      return null;
    }
  }

  Future<bool> addPattern(String code, String pattern) async {
    try {
      await _dio.post(
        '${ApiConstants.expenseCatalog}/$code/patterns',
        data: {'pattern': pattern},
      );
      await fetchCatalog();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<ExpenseCatalogItemModel?> updateItem(String code, Map<String, dynamic> payload) async {
    try {
      final res = await _dio.put(
        '${ApiConstants.expenseCatalog}/$code',
        data: payload,
      );
      final updated = ExpenseCatalogItemModel.fromJson(res.data);
      await fetchCatalog();
      return updated;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteItem(String code) async {
    try {
      await _dio.delete('${ApiConstants.expenseCatalog}/$code');
      await fetchCatalog();
      return true;
    } catch (e) {
      return false;
    }
  }
}


