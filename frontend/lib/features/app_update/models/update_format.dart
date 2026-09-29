import '../../../core/localization/app_localizations.dart';
import 'update_models.dart';

const int _bytesPerMb = 1024 * 1024;

/// Bytes as megabytes with one decimal ("202.8"). Western digits in both
/// languages so sizes and versions read the same in AR and EN.
String formatMegabytes(int bytes) {
  if (bytes <= 0) return '0.0';
  return (bytes / _bytesPerMb).toStringAsFixed(1);
}

/// Installer size label, e.g. "202.8 MB" / "202.8 ميجابايت".
String formatUpdateSize(AppLocalizations l, int bytes) => l.updateSize(formatMegabytes(bytes));

/// Download progress label, e.g. "Downloading… 50.0 of 202.8 MB".
String formatUpdateProgress(AppLocalizations l, int downloadedBytes, int totalBytes) =>
    l.updateDownloading(formatMegabytes(downloadedBytes), formatMegabytes(totalBytes));

/// "Preparing rollback copy… 3.0 of 180.2 MB".
String formatRollbackCopyProgress(AppLocalizations l, int doneBytes, int totalBytes) =>
    l.updatePreparingRollbackCopy(formatMegabytes(doneBytes), formatMegabytes(totalBytes));

/// Whole percent (0-100), or null when unknown.
int? progressPercent(double? progress) => progress == null ? null : (progress * 100).floor().clamp(0, 100);

/// One-line text for a busy [status] (downloading / rollback copy / verifying /
/// backing up / installing), or null for other states. Download sizes use the
/// installer size, never installer + rollback copy.
String? updateBusyText(AppLocalizations l, UpdateStatus status, {int? installerSizeBytes}) {
  switch (status.state) {
    case UpdateState.downloading:
      return formatUpdateProgress(
        l,
        status.displayDownloadedBytes(installerSizeBytes: installerSizeBytes),
        status.displayTotalBytes(installerSizeBytes: installerSizeBytes),
      );
    case UpdateState.verifying:
      if (status.isPreparingRollbackCopy) {
        return status.totalBytes > 0
            ? formatRollbackCopyProgress(l, status.downloadedBytes, status.totalBytes)
            : l.updatePreparingRollbackCopyShort;
      }
      return l.updateVerifying;
    case UpdateState.backingUp:
      return l.updateBackingUp;
    case UpdateState.installing:
      return l.updateInstalling;
    case UpdateState.idle:
    case UpdateState.ready:
    case UpdateState.failed:
    case UpdateState.unknown:
      return null;
  }
}

/// Determinate progress (0.0-1.0) for a busy [status], or null (indeterminate).
double? updateBusyProgress(UpdateStatus status, {int? installerSizeBytes}) {
  if (status.state == UpdateState.downloading) {
    return status.displayProgress(installerSizeBytes: installerSizeBytes);
  }
  if (status.isPreparingRollbackCopy) return status.progress;
  return null;
}

String _two(int v) => v.toString().padLeft(2, '0');

/// Local "yyyy-MM-dd HH:mm" (used for the rollback backup time and last check).
String formatUpdateTimestamp(DateTime? value) {
  if (value == null) return '-';
  final t = value.toLocal();
  return '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';
}
