/// File-picker extension lists that mirror the backend upload allow-lists
/// (`modules/common/upload_guard.py`). Picking a type the server rejects would
/// only surface as a 415 after the upload, so the pickers offer exactly these.
class UploadFileTypes {
  UploadFileTypes._();

  /// Master-data Excel imports and the CargoX standard invoice parse
  /// (backend `EXCEL_EXTENSIONS`; openpyxl cannot read legacy `.xls`).
  static const List<String> excelImport = ['xlsx', 'xlsm'];

  /// Customs tariff bulk upload (backend `TEXT_EXTENSIONS`: parsed as CSV text).
  static const List<String> tariffCsvImport = ['csv', 'txt'];
}
