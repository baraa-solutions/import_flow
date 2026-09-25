import 'dart:convert';
import 'dart:io';

/// Diagnostic sink for the backend launcher (support reads it in production).
/// Callers must never pass tokens / credentials; see [redactUrl].
abstract class LauncherLog {
  void write(String message);

  /// Persist what was written so far (called on READY / FAILED).
  void flush() {}
}

/// Discards everything (web, disabled launcher).
class NullLauncherLog implements LauncherLog {
  const NullLauncherLog();

  @override
  void write(String message) {}

  @override
  void flush() {}
}

/// Appends timestamped lines to [path]. The file is opened once and kept open;
/// its size is tracked in memory and, past [maxBytes], it is rotated once to
/// `<path>.1` (the previous `.1` is dropped). Each line is one write syscall;
/// an fsync happens only on [flush]. Never throws.
class FileLauncherLog implements LauncherLog {
  FileLauncherLog(this.path, {this.maxBytes = 200 * 1024, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final String path;
  final int maxBytes;
  final DateTime Function() _now;

  RandomAccessFile? _file;
  int _size = 0;
  bool _broken = false;

  /// `%LOCALAPPDATA%\SorourLogistics\logs\launcher.log`, or null if unknown.
  static String? defaultPath([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    final base = env['LOCALAPPDATA'];
    if (base == null || base.trim().isEmpty) return null;
    return '$base\\SorourLogistics\\logs\\launcher.log';
  }

  RandomAccessFile? _open() {
    if (_file != null || _broken) return _file;
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      final raf = file.openSync(mode: FileMode.append);
      _size = raf.lengthSync();
      return _file = raf;
    } catch (_) {
      _broken = true; // don't retry on every line
      return null;
    }
  }

  void _rotate() {
    _file?.closeSync();
    _file = null;
    try {
      final rotated = File('$path.1');
      if (rotated.existsSync()) rotated.deleteSync();
      File(path).renameSync(rotated.path);
    } catch (_) {
      // Another frontend.exe may hold the file open: keep appending and retry
      // rotation only after another maxBytes, so no lines are lost.
      _open();
      _size = 0;
    }
  }

  @override
  void write(String message) {
    try {
      if (_open() != null && _size > maxBytes) {
        _rotate();
      }
      final raf = _open();
      if (raf == null) return;
      final line = '${_now().toIso8601String()} [pid $pid] $message\r\n';
      final bytes = utf8.encode(line);
      raf.writeFromSync(bytes);
      _size += bytes.length;
    } catch (_) {
      // Diagnostics must never break startup.
    }
  }

  @override
  void flush() {
    try {
      _file?.flushSync();
    } catch (_) {}
  }

  /// Releases the file handle (tests; the app keeps it for its lifetime).
  void close() {
    try {
      _file?.closeSync();
    } catch (_) {}
    _file = null;
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
