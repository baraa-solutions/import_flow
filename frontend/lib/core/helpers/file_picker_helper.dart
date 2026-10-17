import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

/// Central helper for resolving PlatformFile binary bytes across Web and Desktop (Windows/macOS/Linux).
/// On Windows Desktop, FilePicker.pickFiles often provides `file.path` with `file.bytes == null`.
/// This helper safely loads bytes from `file.path` using synchronous file I/O on desktop.
class FilePickerHelper {
  /// Safely extracts or reads binary bytes for a [PlatformFile].
  static Uint8List? getBytes(PlatformFile file) {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes;
    }
    if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
      try {
        final f = io.File(file.path!);
        if (f.existsSync()) {
          return f.readAsBytesSync();
        }
      } catch (e) {
        debugPrint('[FilePickerHelper] Failed to read bytes from ${file.path}: $e');
      }
    }
    return null;
  }

  /// Returns a clone of [PlatformFile] with [bytes] populated if it was null.
  static PlatformFile withBytes(PlatformFile file) {
    if (file.bytes != null && file.bytes!.isNotEmpty) return file;
    final bytes = getBytes(file);
    if (bytes != null) {
      return PlatformFile(
        name: file.name,
        size: file.size > 0 ? file.size : bytes.length,
        bytes: bytes,
        path: file.path,
        readStream: file.readStream,
      );
    }
    return file;
  }

  /// Resolves an entire list of [PlatformFile] items ensuring each valid file has its [bytes] loaded.
  static List<PlatformFile> resolveFilesWithBytes(List<PlatformFile> files) {
    return files.map((f) => withBytes(f)).where((f) => f.bytes != null && f.bytes!.isNotEmpty).toList();
  }

  static const List<String> _plainTextExtensions = ['txt', 'csv', 'json', 'xml', 'log'];

  /// Whether [name]'s extension (text after the last `.`, case-insensitive)
  /// is a plain-text format whose content can be shown directly in a text field.
  static bool isPlainTextFile(String name) =>
      _plainTextExtensions.contains(name.split('.').last.toLowerCase());

  /// Decodes [bytes] as UTF-8 (malformed sequences allowed).
  /// Returns `null` when [bytes] is null, and an empty string if decoding throws.
  static String? tryDecodeText(Uint8List? bytes) {
    if (bytes == null) return null;
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }
}
