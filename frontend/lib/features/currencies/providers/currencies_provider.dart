import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../models/currency_model.dart';
import '../../../core/network/api_client.dart';


final currenciesProvider =
    StateNotifierProvider<CurrenciesNotifier, AsyncValue<List<CurrencyModel>>>((ref) {
  return CurrenciesNotifier(ref.read(dioProvider));
});

class CurrenciesNotifier extends StateNotifier<AsyncValue<List<CurrencyModel>>> {
  final Dio _dio;
  CancelToken? _cancelToken;

  CurrenciesNotifier(this._dio) : super(const AsyncValue.loading()) {
    fetchCurrencies();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('CurrenciesNotifier disposed');
    super.dispose();
  }

  Future<void> fetchCurrencies({bool includeInactive = true, String? search}) async {
    _cancelToken?.cancel('Cancelled by new fetchCurrencies request');
    _cancelToken = CancelToken();
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, dynamic>{
        'include_inactive': includeInactive,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/currencies',
        queryParameters: queryParams,
        cancelToken: _cancelToken,
      );
      final List data = response.data as List;
      final currencies = data.map((json) => CurrencyModel.fromJson(json)).toList();
      state = AsyncValue.data(currencies);
    } catch (err, stack) {
      if (err is DioException && CancelToken.isCancel(err)) return;
      state = AsyncValue.error(err, stack);
    }
  }

  Future<bool> createCurrency(CurrencyModel model) async {
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/currencies',
        data: model.toJson(),
      );
      await fetchCurrencies();
      return true;
    } catch (err) {
      return false;
    }
  }

  Future<bool> updateCurrency(int id, Map<String, dynamic> data) async {
    try {
      await _dio.put(
        '${ApiConstants.baseUrl}/currencies/$id',
        data: data,
      );
      await fetchCurrencies();
      return true;
    } catch (err) {
      return false;
    }
  }

  Future<bool> toggleActive(int id, bool currentStatus) async {
    try {
      if (currentStatus) {
        await _dio.delete('${ApiConstants.baseUrl}/currencies/$id');
      } else {
        await _dio.post('${ApiConstants.baseUrl}/currencies/$id/restore');
      }
      await fetchCurrencies();
      return true;
    } catch (err) {
      return false;
    }
  }

  Future<bool> addExchangeRate(ExchangeRateModel rate) async {
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/currencies/rates',
        data: rate.toJson(),
      );
      await fetchCurrencies();
      return true;
    } catch (err) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> convertCurrency({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
    String rateType = 'commercial',
    String? asOfDate,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/currencies/convert',
        data: {
          'amount': amount,
          'from_currency_code': fromCurrency,
          'to_currency_code': toCurrency,
          'rate_type': rateType,
          if (asOfDate != null && asOfDate.isNotEmpty) 'as_of_date': asOfDate,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (err) {
      return null;
    }
  }

  /// Get official Egyptian Customs Exchange Rate (سعر الصرف الجمركي) dynamically as of a date
  Future<double?> fetchCustomsExchangeRate({
    required String currencyCode,
    DateTime? onDate,
  }) async {
    final code = currencyCode.trim().toUpperCase();
    if (code == 'EGP' || code.isEmpty) return 1.0;

    final dateStr = onDate != null ? onDate.toIso8601String().substring(0, 10) : null;
    final res = await convertCurrency(
      amount: 1.0,
      fromCurrency: code,
      toCurrency: 'EGP',
      rateType: 'customs',
      asOfDate: dateStr,
    );
    if (res != null && res['applied_rate'] != null) {
      final rate = (res['applied_rate'] as num).toDouble();
      if (rate > 0) return rate;
    }

    // Fallback to loaded currencies list if date is current
    if (onDate == null || dateStr == DateTime.now().toIso8601String().substring(0, 10)) {
      final list = state.valueOrNull ?? [];
      final match = list.where((c) => c.currencyCode.toUpperCase() == code).firstOrNull;
      if (match?.latestCustomsRate != null && match!.latestCustomsRate! > 0) {
        return match.latestCustomsRate!;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> calculateGainLoss({
    required double foreignAmount,
    required String currencyCode,
    required double initialRate,
    required double settlementRate,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/currencies/gain-loss',
        data: {
          'foreign_amount': foreignAmount,
          'currency_code': currencyCode,
          'initial_rate': initialRate,
          'settlement_rate': settlementRate,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (err) {
      return null;
    }
  }

  Future<CurrencyModel?> fetchCurrencyHistory(int currencyId) async {
    try {
      final response = await _dio.get('${ApiConstants.baseUrl}/currencies/$currencyId');
      return CurrencyModel.fromJson(response.data as Map<String, dynamic>);
    } catch (err) {
      return null;
    }
  }
}
