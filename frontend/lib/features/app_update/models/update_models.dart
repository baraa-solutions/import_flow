// Models for the in-app update API (`/api/v1/app-update`, plan §6).
//
// Every parser is null-tolerant: a missing or wrongly typed field falls back to
// a safe default instead of throwing, so a partial backend response never
// breaks the home screen.

DateTime? _parseDate(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

int? _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _parseString(Object? value) {
  if (value == null) return null;
  final s = value.toString();
  return s.isEmpty ? null : s;
}

List<String> _parseStringList(Object? value) {
  if (value is List) {
    return value.where((e) => e != null).map((e) => e.toString()).toList();
  }
  return const [];
}

Map<String, dynamic> _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

/// `check_status` of `GET /check`.
enum UpdateCheckStatus {
  upToDate,
  updateAvailable,
  offline,
  invalidSignature,
  disabled,
  unknown;

  static UpdateCheckStatus parse(Object? raw) {
    switch (raw) {
      case 'up_to_date':
        return UpdateCheckStatus.upToDate;
      case 'update_available':
        return UpdateCheckStatus.updateAvailable;
      case 'offline':
        return UpdateCheckStatus.offline;
      case 'invalid_signature':
        return UpdateCheckStatus.invalidSignature;
      case 'disabled':
        return UpdateCheckStatus.disabled;
      default:
        return UpdateCheckStatus.unknown;
    }
  }
}

/// Release notes in both UI languages (`release_notes: {ar: [...], en: [...]}`).
class UpdateReleaseNotes {
  final List<String> ar;
  final List<String> en;

  const UpdateReleaseNotes({this.ar = const [], this.en = const []});

  factory UpdateReleaseNotes.fromJson(Object? json) {
    final map = _asMap(json);
    return UpdateReleaseNotes(
      ar: _parseStringList(map['ar']),
      en: _parseStringList(map['en']),
    );
  }

  /// Notes for [languageCode]; falls back to the other language when empty.
  List<String> forLanguage(String languageCode) {
    final primary = languageCode == 'ar' ? ar : en;
    if (primary.isNotEmpty) return primary;
    return languageCode == 'ar' ? en : ar;
  }
}

/// `UpdateCheckResponse` of `GET /check`.
class UpdateCheckResult {
  final String currentVersion;
  final int currentBuild;
  final String? latestVersion;
  final int? latestBuild;
  final bool updateAvailable;
  final bool mandatory;
  final UpdateReleaseNotes releaseNotes;
  final DateTime? releasedAt;
  final int? installerSizeBytes;
  final UpdateCheckStatus checkStatus;
  final DateTime? lastCheckedAt;
  final bool applySupported;

  const UpdateCheckResult({
    required this.currentVersion,
    this.currentBuild = 0,
    this.latestVersion,
    this.latestBuild,
    this.updateAvailable = false,
    this.mandatory = false,
    this.releaseNotes = const UpdateReleaseNotes(),
    this.releasedAt,
    this.installerSizeBytes,
    this.checkStatus = UpdateCheckStatus.unknown,
    this.lastCheckedAt,
    this.applySupported = false,
  });

  factory UpdateCheckResult.fromJson(Map<String, dynamic> json) {
    return UpdateCheckResult(
      currentVersion: _parseString(json['current_version']) ?? '',
      currentBuild: _parseInt(json['current_build']) ?? 0,
      latestVersion: _parseString(json['latest_version']),
      latestBuild: _parseInt(json['latest_build']),
      updateAvailable: json['update_available'] == true,
      mandatory: json['mandatory'] == true,
      releaseNotes: UpdateReleaseNotes.fromJson(json['release_notes']),
      releasedAt: _parseDate(json['released_at']),
      installerSizeBytes: _parseInt(json['installer_size_bytes']),
      checkStatus: UpdateCheckStatus.parse(json['check_status']),
      lastCheckedAt: _parseDate(json['last_checked_at']),
      applySupported: json['apply_supported'] == true,
    );
  }

  /// True only for a verified, newer release. Offline, invalid signature,
  /// disabled and up-to-date never produce a notice.
  bool get hasActionableUpdate =>
      updateAvailable &&
      checkStatus == UpdateCheckStatus.updateAvailable &&
      latestVersion != null;
}

/// `state` of `UpdateStatusResponse`.
enum UpdateState {
  idle,
  downloading,
  verifying,
  ready,
  backingUp,
  installing,
  failed,
  unknown;

  static UpdateState parse(Object? raw) {
    switch (raw) {
      case 'idle':
        return UpdateState.idle;
      case 'downloading':
        return UpdateState.downloading;
      case 'verifying':
        return UpdateState.verifying;
      case 'ready':
        return UpdateState.ready;
      case 'backing_up':
        return UpdateState.backingUp;
      case 'installing':
        return UpdateState.installing;
      case 'failed':
        return UpdateState.failed;
      default:
        return UpdateState.unknown;
    }
  }

  /// States during which the UI polls `GET /status` every second.
  bool get isPolling =>
      this == UpdateState.downloading ||
      this == UpdateState.verifying ||
      this == UpdateState.backingUp;
}

/// `phase` of `UpdateStatusResponse`: which file a running download job is
/// fetching. Null outside a running job and on older backends.
enum UpdatePhase {
  /// The new installer (state `downloading`).
  installer,

  /// The previous installer, pre-fetched for rollback (state stays `verifying`).
  rollbackCopy;

  static UpdatePhase? parse(Object? raw) {
    switch (raw) {
      case 'installer':
        return UpdatePhase.installer;
      case 'rollback_copy':
        return UpdatePhase.rollbackCopy;
      default:
        return null;
    }
  }
}

/// `UpdateStatusResponse` of `GET /status`, `POST /download`, `/cancel`, `/stage-local`.
class UpdateStatus {
  final UpdateState state;
  final String? version;
  final int downloadedBytes;
  final int totalBytes;
  final String? errorCode;
  final String? errorDetail;

  /// Which file the running job fetches; `downloadedBytes` / `totalBytes`
  /// always describe that file.
  final UpdatePhase? phase;

  const UpdateStatus({
    this.state = UpdateState.idle,
    this.version,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorCode,
    this.errorDetail,
    this.phase,
  });

  static const idle = UpdateStatus();

  factory UpdateStatus.fromJson(Map<String, dynamic> json) {
    return UpdateStatus(
      state: UpdateState.parse(json['state']),
      version: _parseString(json['version']),
      downloadedBytes: _parseInt(json['downloaded_bytes']) ?? 0,
      totalBytes: _parseInt(json['total_bytes']) ?? 0,
      errorCode: _parseString(json['error_code']),
      errorDetail: _parseString(json['error_detail']),
      phase: UpdatePhase.parse(json['phase']),
    );
  }

  /// 0.0-1.0, or null when the total size is unknown.
  double? get progress {
    if (totalBytes <= 0) return null;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  /// Verifying while the rollback copy (previous installer) is fetched.
  bool get isPreparingRollbackCopy =>
      state == UpdateState.verifying && phase == UpdatePhase.rollbackCopy;

  /// Size shown for the installer download. Older backends reported the new
  /// installer plus the rollback copy as one total (212 MB instead of the
  /// installer's size); when the check knows the installer size and the
  /// reported total is larger (or unknown), the installer size wins.
  int displayTotalBytes({int? installerSizeBytes}) {
    if (phase == UpdatePhase.rollbackCopy) return totalBytes;
    final installer = installerSizeBytes ?? 0;
    if (installer > 0 && (totalBytes <= 0 || totalBytes > installer)) return installer;
    return totalBytes;
  }

  /// Downloaded bytes capped at [displayTotalBytes].
  int displayDownloadedBytes({int? installerSizeBytes}) {
    final total = displayTotalBytes(installerSizeBytes: installerSizeBytes);
    if (total <= 0) return downloadedBytes;
    return downloadedBytes > total ? total : downloadedBytes;
  }

  /// 0.0-1.0 against [displayTotalBytes], or null when unknown.
  double? displayProgress({int? installerSizeBytes}) {
    final total = displayTotalBytes(installerSizeBytes: installerSizeBytes);
    if (total <= 0) return null;
    return (downloadedBytes / total).clamp(0.0, 1.0);
  }
}

/// 202 body of `POST /apply`: `{state: "installing", backup_file}`.
class UpdateApplyResult {
  final String state;
  final String? backupFile;

  const UpdateApplyResult({required this.state, this.backupFile});

  factory UpdateApplyResult.fromJson(Map<String, dynamic> json) => UpdateApplyResult(
        state: _parseString(json['state']) ?? 'installing',
        backupFile: _parseString(json['backup_file']),
      );
}

/// 202 body of `POST /rollback`: `{state: "installing", restored_from}`.
class UpdateRollbackResult {
  final String state;
  final String? restoredFrom;

  const UpdateRollbackResult({required this.state, this.restoredFrom});

  factory UpdateRollbackResult.fromJson(Map<String, dynamic> json) => UpdateRollbackResult(
        state: _parseString(json['state']) ?? 'installing',
        restoredFrom: _parseString(json['restored_from']),
      );
}

enum UpdateResultKind {
  none,
  success,
  failed;

  static UpdateResultKind parse(Object? raw) {
    switch (raw) {
      case 'success':
        return UpdateResultKind.success;
      case 'failed':
        return UpdateResultKind.failed;
      default:
        return UpdateResultKind.none;
    }
  }
}

/// `kind` of `GET /last-result`: what produced the result.
enum UpdateOperationKind {
  update,
  rollback;

  /// Null for older backends that don't send `kind` (treated as an update).
  static UpdateOperationKind? parse(Object? raw) {
    switch (raw) {
      case 'update':
        return UpdateOperationKind.update;
      case 'rollback':
        return UpdateOperationKind.rollback;
      default:
        return null;
    }
  }
}

/// `GET /last-result`: outcome of the last install (post-update health check).
class UpdateLastResult {
  final UpdateResultKind result;

  /// `update` | `rollback`; null when the backend predates the field.
  final UpdateOperationKind? kind;
  final String? fromVersion;
  final String? toVersion;
  final DateTime? finishedAt;
  final String? detail;

  /// Not in the frozen §6 contract. Read when the backend sends it so the
  /// rollback dialog can offer the pre-update backup directly.
  final String? backupFile;
  final DateTime? backupCreatedAt;

  const UpdateLastResult({
    this.result = UpdateResultKind.none,
    this.kind,
    this.fromVersion,
    this.toVersion,
    this.finishedAt,
    this.detail,
    this.backupFile,
    this.backupCreatedAt,
  });

  static const none = UpdateLastResult();

  factory UpdateLastResult.fromJson(Map<String, dynamic> json) => UpdateLastResult(
        result: UpdateResultKind.parse(json['result']),
        kind: UpdateOperationKind.parse(json['kind']),
        fromVersion: _parseString(json['from_version']),
        toVersion: _parseString(json['to_version']),
        finishedAt: _parseDate(json['finished_at']),
        detail: _parseString(json['detail']),
        backupFile: _parseString(json['backup_file']),
        backupCreatedAt: _parseDate(json['backup_created_at']),
      );

  /// True when this result came from a rollback (never offer another one).
  bool get isRollback => kind == UpdateOperationKind.rollback;

  /// Rollback is offered only after an update (or an older backend without `kind`).
  bool get allowsRollback => !isRollback;

  /// Identity used to show the post-update notice only once.
  String get noticeKey =>
      '${kind?.name ?? 'update'}|${result.name}|${toVersion ?? ''}|${finishedAt?.toIso8601String() ?? ''}';
}

/// One line of `GET /history` (`{ts, event, version, detail}`).
class UpdateHistoryItem {
  final DateTime? ts;
  final String event;
  final String? version;
  final String? detail;

  const UpdateHistoryItem({this.ts, required this.event, this.version, this.detail});

  factory UpdateHistoryItem.fromJson(Map<String, dynamic> json) => UpdateHistoryItem(
        ts: _parseDate(json['ts']),
        event: _parseString(json['event']) ?? '',
        version: _parseString(json['version']),
        detail: _parseString(json['detail']),
      );

  static List<UpdateHistoryItem> listFromJson(Object? json) {
    final items = _asMap(json)['items'];
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => UpdateHistoryItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}

/// The pre-update backup a rollback would restore.
class RollbackCandidate {
  final String backupFile;
  final DateTime? backupTime;

  const RollbackCandidate({required this.backupFile, this.backupTime});

  /// Prefers `last-result.backup_file`; otherwise the newest `backup_ok`
  /// history event whose `detail` holds the backup file.
  /// Returns null when the last operation was itself a rollback.
  static RollbackCandidate? resolve(UpdateLastResult? lastResult, List<UpdateHistoryItem> history) {
    if (lastResult != null && !lastResult.allowsRollback) return null;
    final fromResult = lastResult?.backupFile;
    if (fromResult != null) {
      return RollbackCandidate(
        backupFile: fromResult,
        backupTime: lastResult?.backupCreatedAt,
      );
    }
    UpdateHistoryItem? newest;
    for (final item in history) {
      if (item.event != 'backup_ok' || item.detail == null) continue;
      if (newest == null ||
          (item.ts != null && (newest.ts == null || item.ts!.isAfter(newest.ts!)))) {
        newest = item;
      }
    }
    if (newest == null) return null;
    return RollbackCandidate(backupFile: newest.detail!, backupTime: newest.ts);
  }
}
