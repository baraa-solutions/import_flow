/// Unicode bidi isolate helpers.
///
/// SystemMessageRenderer wraps Latin/digit params in Arabic text with LRI/PDI so
/// codes keep their order on screen. Those invisible characters must never
/// reach the clipboard or exported files: every copy/export entry point
/// (CopyHelper, TableCopyHelper, TableExportService, FileSaveHelper.saveText,
/// EnterpriseDataTable) calls [stripBidiIsolates].
library;

/// Left-to-right isolate.
const String lri = '\u2066';

/// Pop directional isolate.
const String pdi = '\u2069';

final RegExp _isolates = RegExp('[\u2066-\u2069]');

/// [text] without bidi isolate characters.
String stripBidiIsolates(String text) =>
    text.contains(_isolates) ? text.replaceAll(_isolates, '') : text;
