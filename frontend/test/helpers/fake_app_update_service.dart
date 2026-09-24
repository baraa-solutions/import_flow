import 'package:frontend/features/app_update/models/update_models.dart';
import 'package:frontend/features/app_update/services/app_update_service.dart';

/// In-memory AppUpdateService for provider / widget tests.
class FakeAppUpdateService implements AppUpdateService {
  FakeAppUpdateService({
    UpdateCheckResult? check,
    List<UpdateStatus>? statuses,
    this.last = UpdateLastResult.none,
    this.historyItems = const [],
  })  : checkResult = check ?? const UpdateCheckResult(currentVersion: '2.0.3', checkStatus: UpdateCheckStatus.upToDate),
        statuses = statuses ?? const [UpdateStatus.idle];

  UpdateCheckResult checkResult;
  List<UpdateStatus> statuses;
  UpdateLastResult last;
  List<UpdateHistoryItem> historyItems;

  /// Thrown by apply / rollback / download when set.
  Object? actionError;

  int checkCalls = 0;
  int statusCalls = 0;
  final List<String> calls = [];

  @override
  Future<UpdateCheckResult> check({bool force = false}) async {
    checkCalls++;
    return checkResult;
  }

  @override
  Future<UpdateStatus> status() async {
    final s = statuses[statusCalls < statuses.length ? statusCalls : statuses.length - 1];
    statusCalls++;
    return s;
  }

  @override
  Future<UpdateStatus> download(String version) async {
    calls.add('download:$version');
    if (actionError != null) throw actionError!;
    return UpdateStatus(state: UpdateState.downloading, version: version, totalBytes: 100);
  }

  @override
  Future<UpdateStatus> cancel() async {
    calls.add('cancel');
    return UpdateStatus.idle;
  }

  @override
  Future<UpdateApplyResult> apply(String version) async {
    calls.add('apply:$version');
    if (actionError != null) throw actionError!;
    return const UpdateApplyResult(state: 'installing', backupFile: 'pre_update/b.db');
  }

  @override
  Future<UpdateStatus> stageLocal({required String manifestPath, required String installerPath}) async {
    calls.add('stage:$manifestPath|$installerPath');
    return const UpdateStatus(state: UpdateState.ready, version: '2.1.0');
  }

  @override
  Future<UpdateRollbackResult> rollback(String backupFile) async {
    calls.add('rollback:$backupFile');
    if (actionError != null) throw actionError!;
    return UpdateRollbackResult(state: 'installing', restoredFrom: backupFile);
  }

  @override
  Future<UpdateLastResult> lastResult() async => last;

  @override
  Future<List<UpdateHistoryItem>> history({int limit = 50}) async => historyItems;
}

const offlineCheck = UpdateCheckResult(
  currentVersion: '2.0.3',
  checkStatus: UpdateCheckStatus.offline,
);

const optionalCheck = UpdateCheckResult(
  currentVersion: '2.0.3',
  latestVersion: '2.1.0',
  updateAvailable: true,
  installerSizeBytes: 212650000,
  releaseNotes: UpdateReleaseNotes(ar: ['تحسينات'], en: ['Improvements']),
  checkStatus: UpdateCheckStatus.updateAvailable,
  applySupported: true,
);

const mandatoryCheck = UpdateCheckResult(
  currentVersion: '2.0.3',
  latestVersion: '2.1.0',
  updateAvailable: true,
  mandatory: true,
  checkStatus: UpdateCheckStatus.updateAvailable,
  applySupported: true,
);
