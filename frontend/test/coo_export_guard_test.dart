import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/import_documentation/services/coo_export_service.dart';
import 'package:frontend/features/import_documentation/services/original_docs_export_service.dart';
import 'package:frontend/features/import_documentation/widgets/visual_draft_coo_sheet.dart';

void main() {
  const goodTemplate = <String, dynamic>{
    'country_of_origin': 'CHINA',
    'box_8_hs_code': '5602290000',
  };

  group('COO: no invented HS code / ACID', () {
    test('formatCooHsCode of an empty value is empty (no 56.02 / 5602290000)', () {
      expect(VisualDraftCOOSheet.formatCooHsCode('', isChina: true), '');
      expect(VisualDraftCOOSheet.formatCooHsCode('', isChina: false), '');
      expect(VisualDraftCOOSheet.formatCooHsCode('   '), '');
      expect(CooExportService.formatCooHsCode('', isChina: true), '');
      expect(CooExportService.formatCooHsCode('', isChina: false), '');
      expect(VisualDraftCOOSheet.formatCooHsCode('5602290000'), '56.02');
    });

    test('export is refused when ACID, HS code or origin is missing', () {
      expect(CooExportService.missingExportField(goodTemplate, ''), 'acid');
      expect(CooExportService.missingExportField(goodTemplate, null), 'acid');
      expect(CooExportService.missingExportField(goodTemplate, 'CN - China'), 'acid');
      expect(CooExportService.missingExportField({'country_of_origin': 'CHINA'}, '7595528271015010011'), 'hs_code');
      expect(CooExportService.missingExportField({'box_8_hs_code': '5602'}, '7595528271015010011'), 'origin');
      expect(CooExportService.missingExportField(goodTemplate, '7595528271015010011'), isNull);
    });

    test('HS code may come from table rows', () {
      final t = {
        'country_of_origin': 'CHINA',
        'table_rows': [
          {'hs_code': ''},
          {'hs_code': '3921900000'},
        ],
      };
      expect(CooExportService.missingExportField(t, '7595528271015010011'), isNull);
    });

    test('CSV export and PDF generation throw for a missing ACID', () async {
      expect(
        () => CooExportService.exportCOOCsv(templateData: goodTemplate, certificateType: 'CHINA CCPIT', acidNumber: ''),
        throwsA(isA<CooExportBlockedException>().having((e) => e.field, 'field', 'acid')),
      );
      await expectLater(
        CooExportService.generateCOOPdf(templateData: goodTemplate, certificateType: 'CHINA CCPIT', acidNumber: ''),
        throwsA(isA<CooExportBlockedException>()),
      );
    });

    test('CSV export never contains a fabricated ACID', () {
      final csv = CooExportService.exportCOOCsv(
        templateData: goodTemplate,
        certificateType: 'CHINA CCPIT',
        acidNumber: '1234567890123456789',
      );
      expect(csv.contains('5281534391023010013'), isFalse);
      expect(csv.contains('7595528271020210010'), isFalse);
    });
  });

  group('Tracking URL: http/https only, no shell', () {
    test('safeHttpUri accepts only absolute http/https URLs', () {
      expect(OriginalDocsExportService.safeHttpUri('https://www.dhl.com/track?x=1&y=2')?.host, 'www.dhl.com');
      expect(OriginalDocsExportService.safeHttpUri('http://example.com'), isNotNull);
      expect(OriginalDocsExportService.safeHttpUri('file:///C:/Windows/System32/cmd.exe'), isNull);
      expect(OriginalDocsExportService.safeHttpUri('javascript:alert(1)'), isNull);
      expect(OriginalDocsExportService.safeHttpUri('ftp://example.com'), isNull);
      expect(OriginalDocsExportService.safeHttpUri('calc.exe'), isNull);
      expect(OriginalDocsExportService.safeHttpUri('https://'), isNull);
      expect(OriginalDocsExportService.safeHttpUri(''), isNull);
      expect(OriginalDocsExportService.safeHttpUri(null), isNull);
    });

    test('AWB and company are percent-encoded so they cannot break out of the URL', () {
      final evil = OriginalDocsExportService.buildCarrierTrackingUrl('DHL', '123" & calc.exe & "');
      expect(evil.contains(' '), isFalse);
      expect(evil.contains('"'), isFalse);
      expect(evil.contains('&calc'), isFalse);
      expect(OriginalDocsExportService.safeHttpUri(evil), isNotNull);

      final generic = OriginalDocsExportService.buildCarrierTrackingUrl('Unknown & Co', 'A1');
      expect(generic.startsWith('https://www.google.com/search?q='), isTrue);
      expect(generic.contains('& Co'), isFalse);
    });
  });
}
