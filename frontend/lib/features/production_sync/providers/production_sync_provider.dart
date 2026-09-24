import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/production_sync_model.dart';
import '../services/production_sync_service.dart';
import '../services/auto_updater_service.dart';

final productionSyncServiceProvider = Provider<ProductionSyncService>((ref) {
  final dio = ref.watch(dioProvider);
  return ProductionSyncService(dio);
});

final autoUpdaterServiceProvider = Provider<AutoUpdaterService>((ref) {
  return AutoUpdaterService(apiDio: ref.watch(dioProvider));
});

final systemVersionInfoProvider = FutureProvider.autoDispose<SystemVersionInfoModel>((ref) async {
  final service = ref.watch(productionSyncServiceProvider);
  return await service.getSystemVersionInfo();
});

final syncComparisonProvider = FutureProvider.autoDispose<SyncComparisonResponseModel>((ref) async {
  final service = ref.watch(productionSyncServiceProvider);
  return await service.getComparison();
});

final backupsListProvider = FutureProvider.autoDispose<List<BackupItemModel>>((ref) async {
  final service = ref.watch(productionSyncServiceProvider);
  return await service.listBackups();
});

final updateCheckStateProvider = StateProvider<AsyncValue<RemoteUpdateCheckResultModel?>>((ref) {
  return const AsyncValue.data(null);
});

// ── Auto-Updater Download State ──────────────────────────────────────────────

class DownloadProgressState {
  final AutoUpdateState state;
  final double progress;        // 0.0 → 1.0
  final int downloadedMb;
  final int totalMb;
  final String? localInstallerPath;
  final String? errorMessage;

  const DownloadProgressState({
    this.state = AutoUpdateState.idle,
    this.progress = 0.0,
    this.downloadedMb = 0,
    this.totalMb = 0,
    this.localInstallerPath,
    this.errorMessage,
  });

  DownloadProgressState copyWith({
    AutoUpdateState? state,
    double? progress,
    int? downloadedMb,
    int? totalMb,
    String? localInstallerPath,
    String? errorMessage,
  }) {
    return DownloadProgressState(
      state: state ?? this.state,
      progress: progress ?? this.progress,
      downloadedMb: downloadedMb ?? this.downloadedMb,
      totalMb: totalMb ?? this.totalMb,
      localInstallerPath: localInstallerPath ?? this.localInstallerPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final downloadProgressProvider =
    StateNotifierProvider<DownloadProgressNotifier, DownloadProgressState>((ref) {
  return DownloadProgressNotifier(ref.watch(autoUpdaterServiceProvider));
});

class DownloadProgressNotifier extends StateNotifier<DownloadProgressState> {
  final AutoUpdaterService _updater;
  CancelToken? _cancelToken;

  DownloadProgressNotifier(this._updater) : super(const DownloadProgressState());

  Future<void> startDownload({
    required String installerUrl,
    required String installerFilename,
    double installerSizeMb = 0,
  }) async {
    _cancelToken = CancelToken();
    state = DownloadProgressState(
      state: AutoUpdateState.downloading,
      totalMb: installerSizeMb.round(),
    );

    try {
      final localPath = await _updater.downloadInstaller(
        installerUrl: installerUrl,
        installerFilename: installerFilename,
        cancelToken: _cancelToken,
        onProgress: (progress, downloadedMb, totalMb) {
          if (mounted) {
            state = state.copyWith(
              progress: progress,
              downloadedMb: downloadedMb,
              totalMb: totalMb,
            );
          }
        },
      );

      if (mounted) {
        state = state.copyWith(
          state: AutoUpdateState.done,
          progress: 1.0,
          localInstallerPath: localPath,
        );
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (mounted) state = const DownloadProgressState(state: AutoUpdateState.idle);
      } else {
        if (mounted) {
          state = state.copyWith(
            state: AutoUpdateState.error,
            errorMessage: 'فشل تنزيل التحديث: ${e.message}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          state: AutoUpdateState.error,
          errorMessage: 'خطأ غير متوقع: $e',
        );
      }
    }
  }

  Future<void> launchAndExit() async {
    final path = state.localInstallerPath;
    if (path == null) return;
    state = state.copyWith(state: AutoUpdateState.launching);
    await _updater.launchInstallerAndExit(path);
  }

  void cancelDownload() {
    _cancelToken?.cancel('User cancelled download');
    state = const DownloadProgressState(state: AutoUpdateState.idle);
  }

  void reset() {
    _cancelToken?.cancel();
    state = const DownloadProgressState(state: AutoUpdateState.idle);
  }
}

// ── Existing notifiers ────────────────────────────────────────────────────────

class ProductionSyncNotifier extends StateNotifier<AsyncValue<SyncActionResponseModel?>> {
  final ProductionSyncService _service;
  final Ref _ref;

  ProductionSyncNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  Future<RemoteUpdateCheckResultModel> checkForUpdates({String? remoteUrl}) async {
    _ref.read(updateCheckStateProvider.notifier).state = const AsyncValue.loading();
    try {
      final result = await _service.checkForUpdates(remoteUrl: remoteUrl);
      _ref.read(updateCheckStateProvider.notifier).state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      _ref.read(updateCheckStateProvider.notifier).state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<SyncActionResponseModel?> syncDevToProd() async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.syncDevToProd();
      state = AsyncValue.data(result);
      _ref.invalidate(syncComparisonProvider);
      _ref.invalidate(backupsListProvider);
      _ref.invalidate(systemVersionInfoProvider);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<SyncActionResponseModel?> pullProdToDev() async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.pullProdToDev();
      state = AsyncValue.data(result);
      _ref.invalidate(syncComparisonProvider);
      _ref.invalidate(backupsListProvider);
      _ref.invalidate(systemVersionInfoProvider);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<BackupItemModel> createManualBackup({String target = 'dev'}) async {
    state = const AsyncValue.loading();
    try {
      final backup = await _service.createManualBackup(target: target);
      state = const AsyncValue.data(null);
      _ref.invalidate(backupsListProvider);
      _ref.invalidate(systemVersionInfoProvider);
      return backup;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<RestoreBackupResponseModel> restoreBackup({
    required String filename,
    String target = 'prod',
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.restoreBackup(filename: filename, target: target);
      state = const AsyncValue.data(null);
      _ref.invalidate(backupsListProvider);
      _ref.invalidate(syncComparisonProvider);
      _ref.invalidate(systemVersionInfoProvider);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final productionSyncNotifierProvider =
    StateNotifierProvider<ProductionSyncNotifier, AsyncValue<SyncActionResponseModel?>>((ref) {
  final service = ref.watch(productionSyncServiceProvider);
  return ProductionSyncNotifier(service, ref);
});

final remoteUpdateCheckProvider = FutureProvider.autoDispose<RemoteUpdateCheckModel>((ref) async {
  final service = ref.watch(productionSyncServiceProvider);
  return await service.checkRemoteUpdate();
});
