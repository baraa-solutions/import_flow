import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/port_storage_model.dart';

final portStorageServiceProvider = Provider<PortStorageService>((ref) {
  final dio = ref.watch(dioProvider);
  return PortStorageService(dio);
});

class PortStorageService {
  final Dio _dio;

  PortStorageService(this._dio);

  Future<PortStorageBreakdownModel> calculateStorage({
    required String terminalCode,
    String containerSize = '20ft',
    bool isReefer = false,
    required String gateInDate,
    required String currentOrGateOutDate,
    String? customsReleaseDate,
    bool includeXray = true,
    bool includeScale = true,
  }) async {
    final response = await _dio.post(
      '/api/v1/port-storage/calculate',
      data: {
        'terminal_code': terminalCode,
        'container_size': containerSize,
        'is_reefer': isReefer,
        'gate_in_date': gateInDate,
        'current_or_gate_out_date': currentOrGateOutDate,
        if (customsReleaseDate != null) 'customs_release_date': customsReleaseDate,
        'include_xray': includeXray,
        'include_scale': includeScale,
      },
    );
    return PortStorageBreakdownModel.fromJson(response.data);
  }

  Future<List<PortTerminalRateModel>> getRates({String? terminalCode}) async {
    final query = <String, dynamic>{};
    if (terminalCode != null && terminalCode.isNotEmpty) {
      query['terminal_code'] = terminalCode;
    }
    final response = await _dio.get('/api/v1/port-storage/rates', queryParameters: query);
    final data = response.data as List;
    return data.map((e) => PortTerminalRateModel.fromJson(e)).toList();
  }

  Future<List<dynamic>> getAccruals({int? importFileId}) async {
    final query = <String, dynamic>{};
    if (importFileId != null) query['import_file_id'] = importFileId;
    final response = await _dio.get('/api/v1/port-storage/accruals', queryParameters: query);
    return response.data as List;
  }
}
