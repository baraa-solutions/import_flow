import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../../../core/constants/api_constants.dart';
import '../models/production_sync_model.dart';

/// States of the in-app auto-update download process.
enum AutoUpdateState {
  idle,
  downloading,
  done,
  launching,
  error,
}

/// Service responsible for downloading and launching the latest installer
/// for in-app silent self-update on Windows.
class AutoUpdaterService {
  /// Authenticated backend client (`dioProvider`, base URL `.../api/v1`).
  final Dio _apiDio;

  /// Plain client for the installer binary. It must NOT carry the JWT because
  /// the installer URL may point to a third-party host (e.g. GitHub releases).
  final Dio _downloadDio;

  AutoUpdaterService({required Dio apiDio, Dio? downloadDio})
      : _apiDio = apiDio,
        _downloadDio = downloadDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(minutes: 30),
              ),
            );

  /// Fetches the latest installer info from the backend API.
  Future<InstallerInfoModel> getInstallerInfo() async {
    final response = await _apiDio.get(
      '${ApiConstants.serverUrl}/api/v1/production-sync/installer-info',
      options: Options(receiveTimeout: const Duration(seconds: 15)),
    );

    if (response.statusCode == 200) {
      return InstallerInfoModel.fromJson(Map<String, dynamic>.from(response.data as Map));
    }
    throw Exception('Failed to fetch installer info: ${response.statusCode}');
  }

  /// Downloads the installer from [installerUrl] to the Windows temp directory.
  /// Reports progress via [onProgress] (0.0 to 1.0).
  /// Returns the local path of the downloaded installer file.
  Future<String> downloadInstaller({
    required String installerUrl,
    required String installerFilename,
    required void Function(double progress, int downloadedMb, int totalMb) onProgress,
    CancelToken? cancelToken,
  }) async {
    final tempBase = Platform.environment['TEMP'] ??
        Platform.environment['TMP'] ??
        Directory.systemTemp.path;
    final tempDir = Directory(p.join(tempBase, 'SorourLogisticsUpdate'));
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }

    final savePath = p.join(tempDir.path, installerFilename);

    // Remove stale file
    final existingFile = File(savePath);
    if (existingFile.existsSync()) {
      existingFile.deleteSync();
    }

    await _downloadDio.download(
      installerUrl,
      savePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final progress = received / total;
          final downloadedMb = (received / (1024 * 1024)).round();
          final totalMb = (total / (1024 * 1024)).round();
          onProgress(progress, downloadedMb, totalMb);
        }
      },
    );

    final downloadedFile = File(savePath);
    if (!downloadedFile.existsSync() || downloadedFile.lengthSync() < 1024) {
      throw Exception('Download failed or file is corrupt. Please try again.');
    }

    return savePath;
  }

  /// Launches the downloaded Inno Setup installer silently and exits the Flutter app.
  Future<void> launchInstallerAndExit(String installerPath) async {
    final file = File(installerPath);
    if (!file.existsSync()) {
      throw Exception('Installer file not found: $installerPath');
    }

    await Process.start(
      installerPath,
      ['/SILENT', '/NORESTART'],
      mode: ProcessStartMode.detached,
    );

    await Future.delayed(const Duration(milliseconds: 600));
    exit(0);
  }

  /// Cleans up the temp update folder.
  void cleanupTempFolder() {
    try {
      final tempBase = Platform.environment['TEMP'] ??
          Platform.environment['TMP'] ??
          Directory.systemTemp.path;
      final tempDir = Directory(p.join(tempBase, 'SorourLogisticsUpdate'));
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  }
}
