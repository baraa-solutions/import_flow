import 'package:flutter/foundation.dart';

import 'update_models.dart';

/// What the sidebar update pill shows.
enum UpdateIndicatorKind {
  none,
  available,
  mandatory,
  downloading,
  preparingRollback,

  /// Verifying / backing up / installing (indeterminate ring).
  working,
  ready,
  failed,
}

/// Snapshot rendered by `UpdateIndicatorPill`. Never affected by
/// "remind me later".
@immutable
class UpdateIndicator {
  final UpdateIndicatorKind kind;
  final String? version;

  /// 0.0-1.0 for downloading / preparingRollback; null = indeterminate.
  final double? progress;

  /// The pending release is mandatory (accent turns crimson).
  final bool mandatory;

  /// False for users without `system.update`: the pill is informational.
  final bool canInstall;

  /// Text for the working state (verifying / backing up / installing).
  final UpdateState? state;

  const UpdateIndicator({
    required this.kind,
    this.version,
    this.progress,
    this.mandatory = false,
    this.canInstall = false,
    this.state,
  });

  static const none = UpdateIndicator(kind: UpdateIndicatorKind.none);

  bool get isVisible => kind != UpdateIndicatorKind.none;

  bool get isBusy =>
      kind == UpdateIndicatorKind.downloading ||
      kind == UpdateIndicatorKind.preparingRollback ||
      kind == UpdateIndicatorKind.working;

  @override
  bool operator ==(Object other) =>
      other is UpdateIndicator &&
      other.kind == kind &&
      other.version == version &&
      other.progress == progress &&
      other.mandatory == mandatory &&
      other.canInstall == canInstall &&
      other.state == state;

  @override
  int get hashCode => Object.hash(kind, version, progress, mandatory, canInstall, state);

  @override
  String toString() =>
      'UpdateIndicator($kind, v$version, progress: $progress, mandatory: $mandatory, canInstall: $canInstall)';
}

/// Pure rule behind the pill:
/// - download / rollback-copy / verify / backup / install progress is shown to
///   everyone (information only for non-admins);
/// - ready and failed are admin states: other users keep seeing the release
///   as available / mandatory because they cannot install or retry;
/// - otherwise a verified newer release -> mandatory / available, else none.
UpdateIndicator resolveUpdateIndicator({
  UpdateCheckResult? check,
  UpdateStatus? status,
  required bool canInstall,
}) {
  final actionable = check != null && check.hasActionableUpdate;
  final mandatory = actionable && check.mandatory;
  final checkVersion = actionable ? check.latestVersion : null;

  UpdateIndicator make(UpdateIndicatorKind kind, {double? progress, String? version}) => UpdateIndicator(
        kind: kind,
        version: version ?? status?.version ?? checkVersion,
        progress: progress,
        mandatory: mandatory,
        canInstall: canInstall,
        state: status?.state,
      );

  if (status != null) {
    switch (status.state) {
      case UpdateState.downloading:
        return make(UpdateIndicatorKind.downloading,
            progress: status.displayProgress(installerSizeBytes: check?.installerSizeBytes));
      case UpdateState.verifying:
        if (status.isPreparingRollbackCopy) {
          return make(UpdateIndicatorKind.preparingRollback, progress: status.progress);
        }
        return make(UpdateIndicatorKind.working);
      case UpdateState.backingUp:
      case UpdateState.installing:
        return make(UpdateIndicatorKind.working);
      case UpdateState.ready:
        if (canInstall) return make(UpdateIndicatorKind.ready);
      case UpdateState.failed:
        if (canInstall) return make(UpdateIndicatorKind.failed);
      case UpdateState.idle:
      case UpdateState.unknown:
        break;
    }
  }
  if (!actionable) return UpdateIndicator.none;
  return make(mandatory ? UpdateIndicatorKind.mandatory : UpdateIndicatorKind.available, version: checkVersion);
}
