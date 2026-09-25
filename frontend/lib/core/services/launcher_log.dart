import 'dart:io';

/// Diagnostic sink for the backend launcher (support reads it in production).
/// Callers must never pass tokens / credentials; see [redactUrl].
abstract class LauncherLog {
  void write(String message);
}

/// Discards everything (web, tests that don't care).
class NullLauncherLog implements LauncherLog {
  const NullLauncherLog();

  @override
  void write(String message) {}
}

/// Keeps lines in memory (tests).
class MemoryLauncherLog implements LauncherLog {
  final List<String> lines = [];

  @override
  void write(String message) => lines.add(message);

  bool any(Pattern pattern) => lines.any((l) => l.contains(pattern));
}

/// Appends timestamped lines to [path]; when the file grows past [maxBytes] it
/// is rotated once to `<path>.1` (the previous `.1` is dropped). Never throws.
class FileLauncherLog implements LauncherLog {
  FileLauncherLog(this.path, {this.maxBytes = 200 * 1024, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final String path;
  final int maxBytes;
  final DateTime Function() _now;
  bool _dirReady = false;

  /// `%LOCALAPPDATA%\SorourLogistics\logs\launcher.log`, or null if unknown.
  static String? defaultPath([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    final base = env['LOCALAPPDATA'];
    if (base == null || base.trim().isEmpty) return null;
    return '$base\\SorourLogistics\\logs\\launcher.log';
  }

  @override
  void write(String message) {
    try {
      final file = File(path);
      if (!_dirReady) {
        file.parent.createSync(recursive: true);
        _dirReady = true;
      }
      if (file.existsSync() && file.lengthSync() > maxBytes) {
        final rotated = File('$path.1');
        if (rotated.existsSync()) rotated.deleteSync();
        file.renameSync(rotated.path);
      }
      file.writeAsStringSync(
        '${_now().toIso8601String()} [pid $pid] $message\r\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Diagnostics must never break startup.
    }
  }
}

/// Drops user-info (`user:pass@`) and query string from a URL before logging.
String redactUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return '<invalid url>';
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
}
