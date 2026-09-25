import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../models/production_sync_model.dart';

class ProductionSyncService {
  final Dio _dio;

  /// [_dio] must be the authenticated client from `dioProvider`
  /// (see `productionSyncServiceProvider`); every path below is absolute.
  ProductionSyncService(this._dio);

  Future<SystemVersionInfoModel> getSystemVersionInfo() async {
    final response = await _dio.get('${ApiConstants.serverUrl}/api/v1/production-sync/version-info');
    if (response.statusCode == 200) {
      return SystemVersionInfoModel.fromJson(Map<String, dynamic>.from(response.data as Map));
    }
    throw Exception('فشل جلب معلومات الإصدار: ${response.statusCode}');
  }

  Future<RemoteUpdateCheckResultModel> checkForUpdates({String? remoteUrl}) async {
    final response = await _dio.get(
      '${ApiConstants.serverUrl}/api/v1/production-sync/check-updates',
      queryParameters: remoteUrl != null ? {'remote_url': remoteUrl} : null,
    );
    if (response.statusCode == 200) {
      return RemoteUpdateCheckResultModel.fromJson(Map<String, dynamic>.from(response.data as Map));
    }
    throw Exception('فشل فحص التحديثات: ${response.statusCode}');
  }

  Future<SyncComparisonResponseModel> getComparison() async {
    final response = await _dio.get('${ApiConstants.serverUrl}/api/v1/production-sync/compare');
    if (response.statusCode == 200) {
      return SyncComparisonResponseModel.fromJson(Map<String, dynamic>.from(response.data as Map));
    }
    throw Exception('فشل جلب مقارنة قاعدة البيانات: ${response.statusCode}');
  }

  Future<BackupItemModel> createManualBackup({String target = 'dev'}) async {
    final response = await _dio.post(
      '${ApiConstants.serverUrl}/api/v1/production-sync/backup',
      queryParameters: {'target': target},
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return BackupItemModel.fromJson(Map<String, dynamic>.from(response.data as Map));
    }
    throw Exception('فشل إنشاء النسخة الاحتياطية: ${response.statusCode}');
  }

  Future<List<BackupItemModel>> listBackups() async {
    final response = await _dio.get('${ApiConstants.serverUrl}/api/v1/production-sync/backups');
    if (response.statusCode == 200) {
      final list = (response.data['backups'] as List<dynamic>? ?? []);
      return list.map((item) => BackupItemModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    }
    throw Exception('فشل جلب قائمة النسخ الاحتياطية: ${response.statusCode}');
  }

  Future<RestoreBackupResponseModel> restoreBackup({
    required String filename,
    String target = 'prod',
  }) async {
    final response = await _dio.post(
      '${ApiConstants.serverUrl}/api/v1/production-sync/restore',
      queryParameters: {'filename': filename, 'target': target},
    );
    if (response.statusCode == 200) {
      return RestoreBackupResponseModel.fromJson(Map<String, dynamic>.from(response.data as Map));
    }
    throw Exception('فشل استعادة النسخة الاحتياطية: ${response.statusCode}');
  }

  Future<RemoteUpdateCheckModel> checkRemoteUpdate() async {
    final response = await _dio.get('${ApiConstants.serverUrl}/api/v1/production-sync/check-update');
    if (response.statusCode == 200) {
      return RemoteUpdateCheckModel.fromJson(Map<String, dynamic>.from(response.data as Map));
    }
    throw Exception('فشل فحص التحديثات: ${response.statusCode}');
  }
}
