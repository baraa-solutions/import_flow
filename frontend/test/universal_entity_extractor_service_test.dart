import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/entity_extractor/extractor_controllers.dart';
import 'package:frontend/core/widgets/entity_extractor/extractor_service.dart';

DioException _dioError(dynamic data, {int status = 422}) {
  final options = RequestOptions(path: '/api/v1/smart-upload/upload/supplier-entity');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: data),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  group('ExtractorService error & result messages', () {
    test('shows the backend detail (e.g. OCR engine missing) instead of a raw exception', () {
      final msg = ExtractorService.describeExtractionError(
        _dioError({'detail': 'No OCR engine is installed on the server'}),
        isArabic: false,
      );
      expect(msg, 'No OCR engine is installed on the server');
    });

    test('falls back to a generic localized message when there is no detail', () {
      final msg = ExtractorService.describeExtractionError(Exception('boom'), isArabic: true);
      expect(msg, contains('خطأ'));
    });

    test('connection errors get a clear retry message', () {
      final options = RequestOptions(path: '/x');
      final msg = ExtractorService.describeExtractionError(
        DioException(requestOptions: options, type: DioExceptionType.connectionError),
        isArabic: false,
      );
      expect(msg, contains('Cannot reach the server'));
    });

    test('zero recognized fields is reported, not a silent success', () {
      final data = {'fields_found': <String>[], 'extracted_fields': <String, dynamic>{}};
      expect(ExtractorService.countFoundFields(data), 0);
      expect(ExtractorService.buildExtractionResultMessage(data, isArabic: false), contains('No fields were recognized'));
    });

    test('result message mentions field count and OCR usage', () {
      final data = {
        'fields_found': ['company_name', 'cargox_id', 'iban'],
        'document_text_info': {'method': 'ocr'},
      };
      expect(ExtractorService.buildExtractionResultMessage(data, isArabic: false), '3 fields recognized (via OCR)');
      expect(ExtractorService.buildExtractionResultMessage(data, isArabic: true), contains('3'));
    });

    test('legacy responses without fields_found are not counted', () {
      expect(ExtractorService.countFoundFields({'extracted_fields': {}}), isNull);
    });

    test('file picker only offers types the backend accepts', () {
      expect(ExtractorService.kExtractorAllowedExtensions, isNot(contains('bmp')));
      expect(ExtractorService.kExtractorAllowedExtensions, isNot(contains('tiff')));
      expect(ExtractorService.kExtractorAllowedExtensions, containsAll(['pdf', 'png', 'jpg', 'jpeg']));
    });
  });

  group('ExtractorControllers.populateFields bank & certificate binding', () {
    test('IBAN never lands in the account number field', () {
      final c = ExtractorControllers();
      addTearDown(c.dispose);
      c.populateFields({'iban': 'EG380019000500000000263180002', 'bank_account': null, 'account_number': null}, 0.9);
      expect(c.ibanCtrl.text, 'EG380019000500000000263180002');
      expect(c.accountNumberCtrl.text, isEmpty);
    });

    test('account number, IBAN, SWIFT and CargoX are routed to their own controllers', () {
      final c = ExtractorControllers();
      addTearDown(c.dispose);
      c.populateFields({
        'account_number': '0532013000',
        'bank_account': '0532013000',
        'iban': 'DE89370400440532013000',
        'swift_code': 'COBADEFFXXX',
        'cargox_id': 'CX-EG-2024-00731',
      }, 0.95);
      expect(c.accountNumberCtrl.text, '0532013000');
      expect(c.bankAccountCtrl.text, '0532013000');
      expect(c.ibanCtrl.text, 'DE89370400440532013000');
      expect(c.swiftCodeCtrl.text, 'COBADEFFXXX');
      expect(c.cargoxIdCtrl.text, 'CX-EG-2024-00731');
    });

    test('trademark certificates toggle their checkboxes and fill numbers', () {
      final c = ExtractorControllers();
      addTearDown(c.dispose);
      c.populateFields({
        'has_wipo': true,
        'wipo_number': '1587432',
        'has_euipo': true,
        'euipo_number': '018234567',
        'has_global_brand': true,
        'global_brand_number': 'GBD-776655',
        'has_iso_9001': true,
        'iso_9001_number': 'Q-12345',
      }, 0.9);
      expect(c.hasWipo, isTrue);
      expect(c.wipoNumberCtrl.text, '1587432');
      expect(c.hasEuipo, isTrue);
      expect(c.euipoNumberCtrl.text, '018234567');
      expect(c.hasGlobalBrand, isTrue);
      expect(c.globalBrandNumberCtrl.text, 'GBD-776655');
      expect(c.hasIso9001, isTrue);
      expect(c.iso9001NumberCtrl.text, 'Q-12345');
    });
  });
}
