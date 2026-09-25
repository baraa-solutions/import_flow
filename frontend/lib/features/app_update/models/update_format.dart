import '../../../core/localization/app_localizations.dart';

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

String _two(int v) => v.toString().padLeft(2, '0');

/// Local "yyyy-MM-dd HH:mm" (used for the rollback backup time and last check).
String formatUpdateTimestamp(DateTime? value) {
  if (value == null) return '-';
  final t = value.toLocal();
  return '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';
}
