import 'local_process_sync_models.dart';
import 'production_sync_service.dart';
import 'local_process_sync_web.dart'
    if (dart.library.io) 'local_process_sync_io.dart';

export 'local_process_sync_models.dart';

/// Abstract service contract for Production Sync Hub.
abstract class LocalProcessSyncService {
  /// [api] is the authenticated backend client used for the server-side
  /// fallback (obtain it via `ref.read(productionSyncServiceProvider)`).
  factory LocalProcessSyncService(ProductionSyncService api) =>
      createLocalProcessSyncService(api);

  String get projectRoot;
  String get devDbPath;
  String get prodDbPath;
  String get backupsPath;

  LocalDbStats getDbStats(String dbPath);
  List<LocalBackupEntry> listBackups();

  Future<int> syncDevToProd({
    required void Function(String line) onOutput,
    required void Function(String line) onError,
    void Function(SyncProgressEvent progress)? onProgress,
    void Function(SyncDiffSummary diffSummary)? onDiffSummary,
  });

  Future<int> pullProdToDev({
    required void Function(String line) onOutput,
    required void Function(String line) onError,
    void Function(SyncProgressEvent progress)? onProgress,
  });

  Future<int> compareDatabases({
    required void Function(String line) onOutput,
    required void Function(String line) onError,
    void Function(SyncDiffSummary diffSummary)? onDiffSummary,
  });

  Future<int> fullBuildAndSync({
    required void Function(String line) onOutput,
    required void Function(String line) onError,
    void Function(SyncProgressEvent progress)? onProgress,
    void Function(SyncDiffSummary diffSummary)? onDiffSummary,
  });

  Future<int> launchProductionApp({
    required void Function(String line) onOutput,
    required void Function(String line) onError,
  });

  Future<int> createManualBackup({
    required void Function(String line) onOutput,
    required void Function(String line) onError,
  });
}
