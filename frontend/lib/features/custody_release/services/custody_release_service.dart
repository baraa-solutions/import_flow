import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../models/custody_release_model.dart';

class CustodyReleaseService {
  final Dio _dio;

  CustodyReleaseService(this._dio);

  Future<List<CustodyReleaseDossierModel>> listDossiers({
    int? importFileId,
    String? status,
    bool? lockActive,
  }) async {
    final queryParams = <String, dynamic>{
      'skip': 0,
      'limit': 100,
      if (importFileId != null) 'import_file_id': importFileId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (lockActive != null) 'lock_active': lockActive,
    };
    final response = await _dio.get(
      ApiConstants.custodyRelease,
      queryParameters: queryParams,
    );
    if (response.statusCode == 200 && response.data != null) {
      final items = response.data['items'] as List<dynamic>? ?? [];
      return items
          .map((item) => CustodyReleaseDossierModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<CustodyReleaseDossierModel> createDossier(Map<String, dynamic> payload) async {
    final response = await _dio.post(
      ApiConstants.custodyRelease,
      data: payload,
    );
    return CustodyReleaseDossierModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CustodyReleaseDossierModel> freezeInWarehouse(int custodyId, Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.custodyRelease}/$custodyId/freeze',
      data: payload,
    );
    return CustodyReleaseDossierModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CustodyReleaseDossierModel> approveFinalClearance(int custodyId, Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.custodyRelease}/$custodyId/final-clearance',
      data: payload,
    );
    return CustodyReleaseDossierModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CustodyReleaseDossierModel> reportBreach(int custodyId, Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '${ApiConstants.custodyRelease}/$custodyId/report-breach',
      data: payload,
    );
    return CustodyReleaseDossierModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteDossier(int custodyId) async {
    await _dio.delete('${ApiConstants.custodyRelease}/$custodyId');
  }
}
