import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/comprehensive_dossier_model.dart';

final comprehensiveDossierServiceProvider = Provider<ComprehensiveDossierService>((ref) {
  final dio = ref.watch(dioProvider);
  return ComprehensiveDossierService(dio);
});

final comprehensiveDossierProvider = FutureProvider.family<ComprehensiveShipmentDossierModel, int>((ref, fileId) async {
  final service = ref.watch(comprehensiveDossierServiceProvider);
  return service.fetchComprehensiveDossier(fileId);
});

/// Helper to force refresh the dossier for a given import file across all screens.
void invalidateDossier(dynamic ref, int importFileId) {
  ref.invalidate(comprehensiveDossierProvider(importFileId));
}

class ComprehensiveDossierService {
  final Dio _dio;

  ComprehensiveDossierService(this._dio);

  Future<ComprehensiveShipmentDossierModel> fetchComprehensiveDossier(int importFileId) async {
    final res = await _dio.get('${ApiConstants.fileClosure}/comprehensive-dossier/$importFileId');
    if (res.statusCode == 200 && res.data != null) {
      return ComprehensiveShipmentDossierModel.fromJson(res.data as Map<String, dynamic>);
    }
    throw Exception('فشل جلب الملف الاستيرادي الشامل');
  }

  Future<DossierExportConfirmResponseModel> confirmDossierExport(
    DossierExportConfirmRequestModel request,
  ) async {
    final res = await _dio.post(
      '${ApiConstants.fileClosure}/confirm-dossier-export',
      data: request.toJson(),
    );
    if (res.statusCode == 200 && res.data != null) {
      return DossierExportConfirmResponseModel.fromJson(res.data as Map<String, dynamic>);
    }
    throw Exception('فشل تأكيد تصدير الملف الشامل');
  }
}
