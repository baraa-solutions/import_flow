import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/upload_file_types.dart';

/// The pickers must offer exactly what the backend upload guard accepts.
void main() {
  test('Excel imports offer xlsx/xlsm only (backend EXCEL_EXTENSIONS)', () {
    expect(UploadFileTypes.excelImport, ['xlsx', 'xlsm']);
    expect(UploadFileTypes.excelImport, isNot(contains('xls')));
  });

  test('Tariff import offers csv/txt (backend TEXT_EXTENSIONS)', () {
    expect(UploadFileTypes.tariffCsvImport, ['csv', 'txt']);
  });
}
