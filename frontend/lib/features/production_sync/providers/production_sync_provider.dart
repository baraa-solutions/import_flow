import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/production_sync_model.dart';
import '../services/production_sync_service.dart';

final productionSyncServiceProvider = Provider<ProductionSyncService>((ref) {
  final dio = ref.watch(dioProvider);
  return ProductionSyncService(dio);
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
