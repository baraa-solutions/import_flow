import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// Browser `window` (the JS global object).
JSObject get _window => globalContext;

/// Creates a JS `Blob` from [bytes]; [mimeType] maps to the Blob `type` option.
JSObject _newBlob(List<int> bytes, [String? mimeType]) {
  final parts = <JSAny>[Uint8List.fromList(bytes).toJS].toJS;
  final blobCtor = _window.getProperty<JSFunction>('Blob'.toJS);
  if (mimeType == null) {
    return blobCtor.callAsConstructor<JSObject>(parts);
  }
  final options = JSObject()..setProperty('type'.toJS, mimeType.toJS);
  return blobCtor.callAsConstructor<JSObject>(parts, options);
}

/// Calls [method] on [target] and awaits the returned JS Promise.
Future<JSAny?> _callAsync(JSObject target, String method, [JSAny? arg]) {
  final promise = arg == null
      ? target.callMethod<JSPromise<JSAny?>>(method.toJS)
      : target.callMethod<JSPromise<JSAny?>>(method.toJS, arg);
  return promise.toDart;
}

/// Reads the `name` property of a JS object as a trimmed Dart string, or null.
String? _readName(JSAny? obj) {
  try {
    if (obj == null || !obj.isA<JSObject>()) return null;
    final value = (obj as JSObject).getProperty<JSAny?>('name'.toJS);
    if (value == null || !value.isA<JSString>()) return null;
    final text = (value as JSString).toDart.trim();
    return text.isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}

/// Builds the options object for `window.showSaveFilePicker`.
JSObject _pickerOptions({
  required String fileName,
  required String mimeType,
  required String description,
  required List<String> extList,
}) {
  final pickerOptions = JSObject()
    ..setProperty('suggestedName'.toJS, fileName.toJS);
  if (extList.isNotEmpty) {
    final acceptObj = JSObject()
      ..setProperty(
        mimeType.toJS,
        extList.map((e) => e.toJS).toList().toJS,
      );
    final typeObj = JSObject()
      ..setProperty('description'.toJS, description.toJS)
      ..setProperty('accept'.toJS, acceptObj);
    pickerOptions.setProperty('types'.toJS, <JSAny>[typeObj].toJS);
  }
  return pickerOptions;
}

/// Calls `window.showSaveFilePicker(options)` synchronously and returns its Promise.
JSPromise<JSObject> _showSaveFilePicker(JSObject pickerOptions) =>
    _window.callMethod<JSPromise<JSObject>>(
      'showSaveFilePicker'.toJS,
      pickerOptions,
    );

/// WebFileSaver implementation for Web using the File System Access API (window.showSaveFilePicker).
///
/// Supported on Chromium-based desktop browsers (Chrome, Edge, Opera, Brave) on HTTPS/localhost.
/// Gracefully detects support, prompts user for save directory & file name, handles AbortError (Cancel),
/// and falls back to anchor download on non-supporting browsers (Firefox, Safari, mobile).
///
/// Uses `dart:js_interop` (the SDK replacement for the removed `dart:js_util` / deprecated `dart:html`).
class WebFileSaver {
  /// Feature-detect File System Access API: 'showSaveFilePicker' in window
  static bool get isSupported {
    try {
      return _window.has('showSaveFilePicker');
    } catch (_) {
      return false;
    }
  }

  /// Prompts user with native Save As file picker via File System Access API.
  ///
  /// Returns:
  /// - `String` (chosen file name/path) upon successful save.
  /// - `null` if the user intentionally clicked 'Cancel' (AbortError).
  /// - Throws exception if API fails unexpectedly or is not supported.
  static Future<String?> saveFileWithPicker({
    required List<int> bytes,
    required String fileName,
    List<String>? allowedExtensions,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('showSaveFilePicker is not supported in this browser');
    }

    try {
      final ext = allowedExtensions != null && allowedExtensions.isNotEmpty
          ? allowedExtensions.first.replaceAll('.', '').toLowerCase().trim()
          : (fileName.contains('.') ? fileName.split('.').last.toLowerCase().trim() : '');

      String mimeType = 'application/octet-stream';
      String description = 'Document';
      List<String> extList = [];

      if (ext == 'pdf') {
        mimeType = 'application/pdf';
        description = 'PDF Document';
        extList = ['.pdf'];
      } else if (ext == 'xlsx') {
        mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        description = 'Excel Spreadsheet';
        extList = ['.xlsx'];
      } else if (ext == 'xls') {
        mimeType = 'application/vnd.ms-excel';
        description = 'Excel 97-2004 Spreadsheet';
        extList = ['.xls'];
      } else if (ext == 'csv') {
        mimeType = 'text/csv';
        description = 'CSV Document';
        extList = ['.csv'];
      } else if (ext == 'png') {
        mimeType = 'image/png';
        description = 'PNG Image';
        extList = ['.png'];
      } else if (ext == 'jpg' || ext == 'jpeg') {
        mimeType = 'image/jpeg';
        description = 'JPEG Image';
        extList = ['.jpg', '.jpeg'];
      } else if (ext == 'txt') {
        mimeType = 'text/plain';
        description = 'Text Document';
        extList = ['.txt'];
      } else if (ext.isNotEmpty) {
        mimeType = 'application/$ext';
        description = '${ext.toUpperCase()} Document';
        extList = ['.${ext.toLowerCase()}'];
      }

      final pickerOptions = _pickerOptions(
        fileName: fileName,
        mimeType: mimeType,
        description: description,
        extList: extList,
      );

      // ⚡ CRITICAL FIX — User Gesture Chain Rule:
      // showSaveFilePicker() MUST be called synchronously within the browser user-gesture
      // handler (onClick). Any await BEFORE this call causes the browser to lose the gesture
      // context → SecurityError: "Must be handling a user gesture to show a file picker."
      //
      // Correct pattern:
      //   1. Call JS method synchronously (no prior await) → gesture chain satisfied ✅
      //   2. Await the returned Promise → browser allows this ✅
      //   3. Write data to the obtained FileHandle stream → safe ✅
      //
      // NEVER do: await someAsyncWork(); then showSaveFilePicker() — this breaks the chain ❌
      final handlePromise = _showSaveFilePicker(pickerOptions);

      // Safe to await from here — gesture chain was honoured by the synchronous JS call above.
      final fileHandle = await handlePromise.toDart;

      // Create writable stream
      final writable = (await _callAsync(fileHandle, 'createWritable'))! as JSObject;

      // Write data as Blob
      await _callAsync(writable, 'write', _newBlob(bytes, mimeType));

      // Close the stream
      await _callAsync(writable, 'close');

      // Retrieve chosen name if available
      return _readName(fileHandle) ?? fileName;
    } catch (e) {
      final errStr = e.toString();
      // AbortError  → user cancelled the dialog → return null silently
      // SecurityError → gesture chain was already broken upstream (caller did await before
      //                 invoking FileSaveHelper) → fall back gracefully without crashing
      bool isGestureCancellation = errStr.contains('AbortError') || errStr.contains('SecurityError');
      // A rejected JS Promise surfaces the raw JS error (e.g. a DOMException) here.
      // ignore: invalid_runtime_check_with_js_interop_types
      final errName = e is JSAny ? _readName(e) : null;
      if (errName == 'AbortError' || errName == 'SecurityError') {
        isGestureCancellation = true;
      }

      if (isGestureCancellation) {
        return null; // Caller will fall back to triggerFallbackDownload
      }
      rethrow;
    }
  }

  /// PHASE 1 — Open the native "Save As" dialog synchronously within the user gesture.
  ///
  /// ⚡ User-Gesture Rule: This method calls `showSaveFilePicker()` WITHOUT any prior `await`,
  /// preserving the browser gesture chain. Must be called directly in an `onPressed` / `onClick`
  /// handler, BEFORE any async API calls.
  ///
  /// Returns a JS `FileSystemFileHandle` on success, or `null` if the user cancelled.
  static Future<dynamic> openFilePicker({
    required String fileName,
    List<String>? allowedExtensions,
  }) async {
    if (!isSupported) return null;

    try {
      final ext = allowedExtensions != null && allowedExtensions.isNotEmpty
          ? allowedExtensions.first.replaceAll('.', '').toLowerCase().trim()
          : (fileName.contains('.') ? fileName.split('.').last.toLowerCase().trim() : '');

      String mimeType = 'application/octet-stream';
      String description = 'Document';
      List<String> extList = [];

      if (ext == 'pdf') { mimeType = 'application/pdf'; description = 'PDF Document'; extList = ['.pdf']; }
      else if (ext == 'xlsx') { mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'; description = 'Excel Spreadsheet'; extList = ['.xlsx']; }
      else if (ext == 'xls') { mimeType = 'application/vnd.ms-excel'; description = 'Excel 97-2004 Spreadsheet'; extList = ['.xls']; }
      else if (ext == 'csv') { mimeType = 'text/csv'; description = 'CSV Document'; extList = ['.csv']; }
      else if (ext == 'zip') { mimeType = 'application/zip'; description = 'ZIP Archive'; extList = ['.zip']; }
      else if (ext == 'png') { mimeType = 'image/png'; description = 'PNG Image'; extList = ['.png']; }
      else if (ext.isNotEmpty) { mimeType = 'application/$ext'; description = '${ext.toUpperCase()} Document'; extList = ['.${ext.toLowerCase()}']; }

      final pickerOptions = _pickerOptions(
        fileName: fileName,
        mimeType: mimeType,
        description: description,
        extList: extList,
      );

      // ⚡ SYNCHRONOUS call — no await before this line → gesture chain preserved ✅
      final handlePromise = _showSaveFilePicker(pickerOptions);
      // Now safe to await — gesture was honoured above
      final fileHandle = await handlePromise.toDart;
      return fileHandle;
    } catch (e) {
      // AbortError = user cancelled the dialog
      return null;
    }
  }

  /// PHASE 2 — Write bytes to a pre-opened [FileSystemFileHandle].
  ///
  /// Call this AFTER fetching bytes from an API or performing any async work.
  /// The file handle was already obtained in Phase 1 (inside the user gesture).
  ///
  /// Returns the saved file name, or `null` on failure.
  static Future<String?> writeToFileHandle({
    required dynamic fileHandle,
    required List<int> bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    try {
      final handle = fileHandle as JSObject;
      final writable = (await _callAsync(handle, 'createWritable'))! as JSObject;

      await _callAsync(writable, 'write', _newBlob(bytes, mimeType));

      await _callAsync(writable, 'close');

      return _readName(handle) ?? '';
    } catch (e) {
      return null;
    }
  }

  static void triggerFallbackDownload({
    required List<int> bytes,
    required String fileName,
  }) {
    final blob = _newBlob(bytes);
    final urlApi = _window.getProperty<JSObject>('URL'.toJS);
    final url = urlApi.callMethod<JSString>('createObjectURL'.toJS, blob);
    final document = _window.getProperty<JSObject>('document'.toJS);
    final anchor = document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS)
      ..setProperty('href'.toJS, url)
      ..setProperty('target'.toJS, 'blank'.toJS)
      ..setProperty('download'.toJS, fileName.toJS);
    final body = document.getProperty<JSObject?>('body'.toJS);
    body?.callMethod<JSAny?>('append'.toJS, anchor);
    anchor.callMethod<JSAny?>('click'.toJS);
    anchor.callMethod<JSAny?>('remove'.toJS);
    urlApi.callMethod<JSAny?>('revokeObjectURL'.toJS, url);
  }
}
