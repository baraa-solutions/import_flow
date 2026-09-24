import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../models/update_models.dart';

/// Thin HTTP wrapper over `/api/v1/app-update` (plan §6).
///
/// Uses the authenticated `dioProvider` client. Downloading, hashing,
/// signature checks, backups and launching the installer all happen in the
/// backend; Flutter only asks and shows progress.
class AppUpdateService {
  final Dio _dio;

  AppUpdateService(this._dio);

  Map<String, dynamic> _map(Response<dynamic> r) =>
      r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};

  Future<UpdateCheckResult> check({bool force = false}) async {
    final r = await _dio.get<dynamic>(
      ApiConstants.appUpdateCheck,
      queryParameters: force ? {'force': true} : null,
    );
    return UpdateCheckResult.fromJson(_map(r));
  }

  Future<UpdateStatus> status() async {
    final r = await _dio.get<dynamic>(ApiConstants.appUpdateStatus);
    return UpdateStatus.fromJson(_map(r));
  }

  Future<UpdateStatus> download(String version) async {
    final r = await _dio.post<dynamic>(ApiConstants.appUpdateDownload, data: {'version': version});
    return UpdateStatus.fromJson(_map(r));
  }

  Future<UpdateStatus> cancel() async {
    final r = await _dio.post<dynamic>(ApiConstants.appUpdateCancel);
    return UpdateStatus.fromJson(_map(r));
  }

  Future<UpdateApplyResult> apply(String version) async {
    final r = await _dio.post<dynamic>(ApiConstants.appUpdateApply, data: {'version': version});
    return UpdateApplyResult.fromJson(_map(r));
  }

  Future<UpdateStatus> stageLocal({required String manifestPath, required String installerPath}) async {
    final r = await _dio.post<dynamic>(
      ApiConstants.appUpdateStageLocal,
      data: {'manifest_path': manifestPath, 'installer_path': installerPath},
    );
    return UpdateStatus.fromJson(_map(r));
  }

  Future<UpdateRollbackResult> rollback(String backupFile) async {
    final r = await _dio.post<dynamic>(
      ApiConstants.appUpdateRollback,
      data: {'confirm': true, 'backup_file': backupFile},
    );
    return UpdateRollbackResult.fromJson(_map(r));
  }

  Future<UpdateLastResult> lastResult() async {
    final r = await _dio.get<dynamic>(ApiConstants.appUpdateLastResult);
    return UpdateLastResult.fromJson(_map(r));
  }

  Future<List<UpdateHistoryItem>> history({int limit = 50}) async {
    final r = await _dio.get<dynamic>(ApiConstants.appUpdateHistory, queryParameters: {'limit': limit});
    return UpdateHistoryItem.listFromJson(r.data);
  }
}
