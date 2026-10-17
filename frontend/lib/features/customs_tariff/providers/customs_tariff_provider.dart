import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../audit_logs/providers/audit_logs_provider.dart';
import '../models/customs_tariff_model.dart';
import '../../../core/network/api_client.dart';


import '../services/customs_exemption_engine.dart';


final showInactiveCustomsTariffsProvider = StateProvider<bool>((ref) => false);
final customsTariffSearchQueryProvider = StateProvider<String>((ref) => '');

final customsExemptionEngineProvider = Provider<CustomsExemptionEngine>((ref) {
  return CustomsExemptionEngine(ref.read(dioProvider));
});

final customsTariffProvider = StateNotifierProvider<CustomsTariffNotifier,
    AsyncValue<List<CustomsTariffModel>>>((ref) {
  final showInactive = ref.watch(showInactiveCustomsTariffsProvider);
  final search = ref.watch(customsTariffSearchQueryProvider);
  return CustomsTariffNotifier(ref: ref, showInactive: showInactive, search: search, dio: ref.read(dioProvider));
});

class CustomsTariffNotifier
    extends StateNotifier<AsyncValue<List<CustomsTariffModel>>> {
  final Ref ref;
  final Dio _dio;
  final bool showInactive;
  final String search;
  CancelToken? _cancelToken;

  CustomsTariffNotifier({
    required this.ref,
    required this.showInactive,
    required this.search,
    required Dio dio,
  }) : _dio = dio, super(const AsyncValue.loading()) {
    fetchTariffs();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('CustomsTariffNotifier disposed');
    super.dispose();
  }

  Future<void> fetchTariffs() async {
    _cancelToken?.cancel('Cancelled by new fetchTariffs request');
    _cancelToken = CancelToken();
    state = const AsyncValue.loading();
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/customs-tariff',
        queryParameters: {
          'include_inactive': showInactive,
          if (search.isNotEmpty) 'search': search,
          'limit': 500,
        },
        cancelToken: _cancelToken,
      );
      final list = (response.data as List)
          .map((json) => CustomsTariffModel.fromJson(json))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      state = AsyncValue.error(e, stack);
    }
  }

  String _formatDioError(dynamic e, String defaultMsg) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is Map && detail['message'] != null) return detail['message'].toString();
        if (detail is List) {
          final lines = <String>[];
          for (var item in detail) {
            if (item is Map) {
              final loc = (item['loc'] as List?)
                      ?.where((p) => p.toString() != 'body')
                      .join(' ➔ ') ??
                  '';
              final msg = item['msg']?.toString() ?? item.toString();
              lines.add(loc.isNotEmpty ? '• $loc: $msg' : '• $msg');
            } else {
              lines.add('• ${item.toString()}');
            }
          }
          return 'أخطاء في التحقق من البيانات:\n${lines.join('\n')}';
        }
        if (data['message'] != null) return data['message'].toString();
        return data.toString();
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'انتهت مهلة الاتصال بالخادم. يرجى التأكد من تشغيل السيرفر.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'تعذر الاتصال بخادم الباك إند (${ApiConstants.serverUrl}). يرجى التأكد من تشغيل السيرفر.';
      }
      return e.message ?? defaultMsg;
    }
    return '$defaultMsg\nالتفاصيل: ${e.toString()}';
  }

  Future<String?> createTariff(Map<String, dynamic> data) async {
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/customs-tariff',
        data: data,
      );
      ref.invalidate(systemAuditLogsProvider);
      await fetchTariffs();
      return null;
    } on DioException catch (e) {
      return _formatDioError(e, 'فشل في إضافة البند الجمركي.');
    } catch (e) {
      return 'حدث خطأ أثناء الإضافة:\n$e';
    }
  }

  Future<String?> updateTariff(int tariffId, Map<String, dynamic> data) async {
    try {
      await _dio.put(
        '${ApiConstants.baseUrl}/customs-tariff/$tariffId',
        data: data,
      );
      ref.invalidate(systemAuditLogsProvider);
      await fetchTariffs();
      return null;
    } on DioException catch (e) {
      return _formatDioError(e, 'فشل في تحديث البند الجمركي.');
    } catch (e) {
      return 'حدث خطأ أثناء التحديث:\n$e';
    }
  }

  Future<bool> toggleActive(int tariffId, bool currentlyActive) async {
    try {
      if (currentlyActive) {
        await _dio.delete('${ApiConstants.baseUrl}/customs-tariff/$tariffId');
      } else {
        await _dio.patch('${ApiConstants.baseUrl}/customs-tariff/$tariffId/restore');
      }
      ref.invalidate(systemAuditLogsProvider);
      await fetchTariffs();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CustomsDutyBreakdownModel?> estimateDuty({
    required String hsCode,
    required double cifValue,
    required double freight,
    String? originCountry,
    double packagingEgp = 0.0,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        'hs_code': hsCode,
        'cif_value': cifValue,
        'freight': freight,
        'packaging_egp': packagingEgp,
      };
      if (originCountry != null && originCountry.isNotEmpty) {
        requestData['origin_country'] = originCountry.toUpperCase();
      }
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-tariff/estimate',
        data: requestData,
      );
      return CustomsDutyBreakdownModel.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_formatDioError(e, 'فشل في احتساب الضريبة الجمركية.'));
    } catch (e) {
      throw Exception('حدث خطأ أثناء الحساب: $e');
    }
  }

  Future<Map<String, dynamic>?> estimateMultiItemDuty(Map<String, dynamic> requestData) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-tariff/estimate-multi',
        data: requestData,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_formatDioError(e, 'فشل في احتساب الرسوم للأصناف المتعددة.'));
    } catch (e) {
      throw Exception('حدث خطأ أثناء الحساب: $e');
    }
  }

  Future<Map<String, dynamic>?> simulateImportFileDuties(
    int importFileId, [
    Map<String, dynamic>? requestData,
  ]) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-tariff/simulate-file/$importFileId',
        data: requestData ?? {},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_formatDioError(e, 'فشل في محاكاة واحتساب الرسوم الجمركية لملف الاستيراد.'));
    } catch (e) {
      throw Exception('حدث خطأ أثناء محاكاة الرسوم لملف الاستيراد: $e');
    }
  }

  Future<Map<String, dynamic>?> uploadExcelTariffs(List<int> bytes, String filename) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-tariff/upload-excel',
        data: formData,
      );
      ref.invalidate(systemAuditLogsProvider);
      await fetchTariffs();
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _formatDioError(e, 'فشل في رفع ملف الإكسيل.');
    } catch (e) {
      throw 'حدث خطأ أثناء رفع الملف:\n$e';
    }
  }

  Future<String?> verifyTariff(String hsCode, Map<String, dynamic> data) async {
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/customs-tariff/hs/$hsCode/verify',
        data: data,
      );
      ref.invalidate(systemAuditLogsProvider);
      await fetchTariffs();
      return null;
    } on DioException catch (e) {
      return _formatDioError(e, 'فشل في التحقق/تحديث البند الجمركي.');
    } catch (e) {
      return 'حدث خطأ أثناء التحقق:\n$e';
    }
  }

  Future<List<Map<String, dynamic>>> fetchAgreements(String hsCode) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/customs-tariff/hs/$hsCode/agreements',
      );
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<String?> createPreferentialAgreement(Map<String, dynamic> data) async {
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/customs-tariff/agreements',
        data: data,
      );
      ref.invalidate(systemAuditLogsProvider);
      await fetchTariffs();
      return null;
    } on DioException catch (e) {
      return _formatDioError(e, 'فشل في إضافة الاتفاقية التفضيلية.');
    } catch (e) {
      return 'حدث خطأ أثناء إضافة الاتفاقية:\n$e';
    }
  }

  Future<Map<String, dynamic>?> parseSmartNafezaText(String rawText) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-tariff/parse-text',
        data: {'raw_text': rawText},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _formatDioError(e, 'فشل في تحليل نص البند الجمركي.');
    } catch (e) {
      throw 'حدث خطأ أثناء تحليل النص:\n$e';
    }
  }

  Future<String?> saveTariffWithAgreements(Map<String, dynamic> payload) async {
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/customs-tariff/with-agreements',
        data: payload,
      );
      ref.invalidate(systemAuditLogsProvider);
      await fetchTariffs();
      return null;
    } on DioException catch (e) {
      return _formatDioError(e, 'فشل في حفظ البند الجمركي بالاتفاقيات.');
    } catch (e) {
      return 'حدث خطأ أثناء الحفظ:\n$e';
    }
  }

  Future<Map<String, dynamic>?> checkDutyForOrigin({
    required String hsCode,
    required String originCountry,
    bool hasPreferentialDocument = false,
    DateTime? checkDate,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/customs-tariff/check-duty-for-origin',
        data: {
          'hs_code': hsCode,
          'origin_country': originCountry,
          'has_preferential_document': hasPreferentialDocument,
          if (checkDate != null)
            'check_date': checkDate.toIso8601String().substring(0, 10),
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchTariffHistory(String hsCode) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/customs-tariff/history/$hsCode',
      );
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
