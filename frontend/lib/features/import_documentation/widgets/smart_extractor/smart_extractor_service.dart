import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/api_constants.dart';

/// Network service for Smart Extractor AI endpoints.
class SmartExtractorService {
  /// Extracts structured data from a commercial invoice document or raw text.
  static Future<Map<String, dynamic>?> extractCommercialInvoice({
    required Dio uploadDio,
    PlatformFile? file,
    String? rawText,
  }) async {
    final url = '${ApiConstants.smartDocumentUpload}/extract/commercial-invoice';
    final trimmedText = rawText?.trim() ?? '';

    Response resp;
    if (file != null && file.bytes != null) {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        ),
        if (trimmedText.isNotEmpty) 'raw_text': trimmedText,
      });
      resp = await uploadDio.post(url, data: formData);
    } else {
      final formData = FormData.fromMap({'raw_text': trimmedText});
      resp = await uploadDio.post(url, data: formData);
    }

    if (resp.statusCode == 200 && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }

  /// Extracts structured data from a Bill of Lading or Air Waybill.
  static Future<Map<String, dynamic>?> extractBillOfLading({
    required Dio uploadDio,
    PlatformFile? file,
    String? rawText,
  }) async {
    final url = '${ApiConstants.smartDocumentUpload}/extract/bill-of-lading';
    final trimmedText = rawText?.trim() ?? '';

    Response resp;
    if (file != null && file.bytes != null) {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        ),
        if (trimmedText.isNotEmpty) 'raw_text': trimmedText,
      });
      resp = await uploadDio.post(url, data: formData);
    } else {
      final formData = FormData.fromMap({'raw_text': trimmedText});
      resp = await uploadDio.post(url, data: formData);
    }

    if (resp.statusCode == 200 && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }

  /// Cross-checks invoice data against bill of lading data for discrepancy radar.
  static Future<Map<String, dynamic>?> crossCheckInvoiceVsBL({
    required Dio dio,
    required Map<String, dynamic> invoiceData,
    required Map<String, dynamic> blData,
  }) async {
    final url = '${ApiConstants.smartDocumentUpload}/cross-check/invoice-vs-bl';
    final resp = await dio.post(url, data: {
      'invoice_data': invoiceData,
      'bl_data': blData,
    });
    if (resp.statusCode == 200 && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }

  /// Applies extracted commercial invoice data to a specific import file.
  static Future<bool> applyCommercialInvoice({
    required Dio dio,
    required int importFileId,
    required Map<String, dynamic> invoiceData,
  }) async {
    final url = '${ApiConstants.smartDocumentUpload}/apply/commercial-invoice';
    final resp = await dio.post(url, data: {
      'import_file_id': importFileId,
      'invoice_data': invoiceData,
    });
    return resp.statusCode == 200;
  }

  /// Applies extracted bill of lading data to shipment cargo files.
  /// Returns a map with 'applied': bool, and optional 'message': String.
  static Future<Map<String, dynamic>> applyBillOfLading({
    required Dio dio,
    required int importFileId,
    required Map<String, dynamic> blData,
  }) async {
    final url = '${ApiConstants.smartDocumentUpload}/apply/bill-of-lading';
    final resp = await dio.post(url, data: {
      'import_file_id': importFileId,
      'bl_data': blData,
    });

    if (resp.statusCode == 200) {
      final data = resp.data;
      final applied = !(data is Map && data['applied'] == false);
      final msg = (data is Map ? data['message']?.toString() : null) ?? '';
      return {'applied': applied, 'message': msg};
    }
    return {'applied': false, 'message': ''};
  }
}
