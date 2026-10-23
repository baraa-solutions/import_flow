import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../models/smart_document_upload_model.dart';

class SmartDocumentUploadService {
  final Dio _dio;

  SmartDocumentUploadService(this._dio);

  Future<List<UploadSessionModel>> listSessions({String? moduleName}) async {
    final queryParams = <String, dynamic>{
      'skip': 0,
      'limit': 100,
      if (moduleName != null && moduleName.isNotEmpty) 'module_name': moduleName,
    };
    final response = await _dio.get(
      '${ApiConstants.smartDocumentUpload}/sessions',
      queryParameters: queryParams,
    );
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((item) => UploadSessionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<UploadSessionModel> getSession(int sessionId) async {
    final response = await _dio.get('${ApiConstants.smartDocumentUpload}/sessions/$sessionId');
    return UploadSessionModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteSession(int sessionId) async {
    await _dio.delete('${ApiConstants.smartDocumentUpload}/sessions/$sessionId');
  }

  Future<List<String>> listSupportedModules() async {
    final response = await _dio.get('${ApiConstants.smartDocumentUpload}/modules');
    if (response.statusCode == 200 && response.data != null) {
      final list = response.data['supported_modules'] as List<dynamic>? ?? [];
      return list.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> parseRawText(String module, String rawText) async {
    final formData = FormData.fromMap({
      'raw_text': rawText,
      'save_session': true,
    });
    final response = await _dio.post(
      '${ApiConstants.smartDocumentUpload}/parse-text/$module',
      data: formData,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> crossCheckInvoiceVsBL({
    required Map<String, dynamic> invoiceData,
    required Map<String, dynamic> blData,
    double tolerance = 3.0,
  }) async {
    final response = await _dio.post(
      '${ApiConstants.smartDocumentUpload}/cross-check/invoice-vs-bl',
      data: {
        'invoice_data': invoiceData,
        'bl_data': blData,
        'weight_tolerance_pct': tolerance,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
