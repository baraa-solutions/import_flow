import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/localization/domain_enum_labels.dart';
import 'package:frontend/core/localization/system_messages/coded_item_text.dart';
import 'package:frontend/core/localization/system_messages/system_message_renderer.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/import_documentation/models/import_documentation_model.dart';

/// Document-comparison items (draft B/L, COO, inspection, PO reconciliation,
/// invoice-vs-B/L): `X_code` + `X_params` and `structured_values` render in the
/// user's language; legacy rows keep their stored text.
void main() {
  const en = AppLocalizationsEn();
  const ar = AppLocalizationsAr();

  final cooRow = <String, dynamic>{
    'field': 'exporter_name',
    'draft_value': 'Not extracted',
    'system_value': 'ACME GmbH',
    'match_status': 'MISSING_IN_DRAFT',
    'details': 'Value not found in the certificate of origin draft',
    'details_code': 'DOC_COO_VALUE_NOT_FOUND',
    'details_params': <String, dynamic>{},
    'structured_values': {
      'draft_value': {'placeholder': 'NOT_EXTRACTED'},
    },
  };

  group('CodedItemText.localizeRow', () {
    test('renders details and placeholders in Arabic and English', () {
      final arRow = CodedItemText.localizeRow(cooRow, ar);
      expect(arRow['details'], 'لم يتم العثور على القيمة في مسودة شهادة المنشأ');
      expect(arRow['draft_value'], 'لم يتم الاستخراج');
      expect(arRow['system_value'], 'ACME GmbH');

      final enRow = CodedItemText.localizeRow(cooRow, en);
      expect(enRow['details'], 'Value not found in the certificate of origin draft');
      expect(enRow['draft_value'], 'Not extracted');
    });

    test('does not modify the source row', () {
      CodedItemText.localizeRow(cooRow, ar);
      expect(cooRow['details'], 'Value not found in the certificate of origin draft');
      expect(cooRow['draft_value'], 'Not extracted');
    });

    test('legacy row (Arabic text, no code) is shown as stored in both languages', () {
      final legacy = {
        'details': 'نسبة التشابه: 91.5%',
        'draft_value': 'لم يتم الاستخراج',
      };
      for (final l10n in [ar, en]) {
        final row = CodedItemText.localizeRow(legacy, l10n);
        expect(row['details'], 'نسبة التشابه: 91.5%');
        expect(row['draft_value'], 'لم يتم الاستخراج');
      }
    });

    test('unknown code (newer backend) falls back to the stored English text', () {
      final row = CodedItemText.localizeRow({
        'details': 'Something new',
        'details_code': 'DOC_FUTURE_CODE',
        'details_params': <String, dynamic>{},
      }, ar);
      expect(row['details'], 'Something new');
    });

    test('a missing param falls back to the stored text', () {
      final row = CodedItemText.localizeRow({
        'details': 'Similarity: {match_pct}%',
        'details_code': 'DOC_COO_SIMILARITY',
        'details_params': <String, dynamic>{},
      }, ar);
      expect(row['details'], 'Similarity: {match_pct}%');
    });

    test('numbers and params are formatted; values keep their order in Arabic', () {
      final row = CodedItemText.localizeRow({
        'details': 'Mismatch! System value: \'A-1\' | Draft value: \'B-2\'.',
        'details_code': 'DOC_DRAFT_VALUE_MISMATCH',
        'details_params': {'system_value': 'A-1', 'draft_value': 'B-2'},
        'tolerance': '',
      }, ar);
      final text = row['details'] as String;
      expect(SystemMessageRenderer.stripIsolates(text), "عدم تطابق! قيمة النظام: 'A-1' | قيمة الدرافت: 'B-2'.");
      expect(text, contains(SystemMessageRenderer.lri));

      final pct = CodedItemText.localizeRow({
        'details': 'Similarity: 91.5%',
        'details_code': 'DOC_COO_SIMILARITY',
        'details_params': {'match_pct': 91.5},
      }, ar);
      expect(SystemMessageRenderer.stripIsolates(pct['details'] as String), 'نسبة التشابه: 91.5%');
    });

    test('forExport strips the bidi isolates', () {
      final item = {
        'details': 'x',
        'details_code': 'DOC_CHK_HS_CODE_MISMATCH',
        'details_params': {'document_value': '8501.10', 'system_value': '8502.20'},
      };
      final screen = CodedItemText.localizeRow(item, ar)['details'] as String;
      final export = CodedItemText.localizeRow(item, ar, forExport: true)['details'] as String;
      expect(screen, contains(SystemMessageRenderer.lri));
      expect(export, isNot(contains(SystemMessageRenderer.lri)));
      expect(export, 'البند الجمركي المستخرج (8501.10) يختلف عن المسجل (8502.20)');
    });

    test('tolerance is rendered like details (invoice vs B/L matrix)', () {
      final row = CodedItemText.localizeRow({
        'tolerance': '0% (exact match required)',
        'tolerance_code': 'DOC_TOL_EXACT',
        'tolerance_params': <String, dynamic>{},
        'check_code': 'CHK_ACID', // not a message: `check_params` is absent, so it is left alone
      }, ar);
      expect(row['tolerance'], '0% (مطابقة حتمية تامة)');
      expect(row.containsKey('check'), isFalse);
    });
  });

  group('structured values', () {
    test('number + unit render with the unit label of each language', () {
      final item = {
        'system_value': '1,234.50 kg',
        'structured_values': {
          'system_value': {'number': 1234.5, 'unit': 'KG'},
        },
      };
      expect(CodedItemText.value(item, 'system_value', en), '1,234.50 kg');
      expect(CodedItemText.value(item, 'system_value', ar), '1,234.50 كجم');
    });

    test('package counts are whole numbers; CBM has two decimals', () {
      expect(CodedItemText.structuredValue({'number': 12, 'unit': 'PACKAGES'}, ar), '12 طرد');
      expect(CodedItemText.structuredValue({'number': 12, 'unit': 'PACKAGES'}, en), '12 packages');
      expect(CodedItemText.structuredValue({'number': 3.5, 'unit': 'CBM'}, ar), '3.50 م³');
      expect(CodedItemText.structuredValue({'number': 3.5, 'unit': 'CBM'}, en), '3.50 CBM');
      expect(CodedItemText.structuredValue({'number': 4200, 'unit': 'PACKAGES_PALLETS'}, ar), '4,200 طرد/بالتة');
    });

    test('a non-numeric raw value keeps its text next to the unit', () {
      expect(CodedItemText.structuredValue({'number': null, 'raw': 'n/a', 'unit': 'KG'}, ar), 'n/a كجم');
    });

    test('unknown shape falls back to the stored value', () {
      final item = {
        'draft_value': 'stored',
        'structured_values': {
          'draft_value': {'weird': true},
        },
      };
      expect(CodedItemText.value(item, 'draft_value', ar), 'stored');
      expect(CodedItemText.value(<String, dynamic>{}, 'draft_value', ar, fallback: '—'), '—');
    });

    test('every backend placeholder and unit has a label in both languages', () {
      for (final code in DomainEnums.codesOf(DomainEnumType.valuePlaceholder)) {
        expect(DomainEnums.label(ar, DomainEnumType.valuePlaceholder, code), isNot(code));
        expect(DomainEnums.label(en, DomainEnumType.valuePlaceholder, code), isNot(code));
      }
      for (final code in DomainEnums.codesOf(DomainEnumType.measureUnit)) {
        expect(DomainEnums.label(ar, DomainEnumType.measureUnit, code), isNotEmpty);
        expect(DomainEnums.label(en, DomainEnumType.measureUnit, code), isNotEmpty);
      }
    });

    test('legacy placeholder labels map to their code', () {
      expect(DomainEnums.legacyToCode(DomainEnumType.valuePlaceholder, 'غير محدد بالسستم'), 'NOT_SET');
      expect(DomainEnums.legacyToCode(DomainEnumType.valuePlaceholder, 'لم يتم الاستخراج'), 'NOT_EXTRACTED');
      expect(DomainEnums.legacyToCode(DomainEnumType.measureUnit, 'كجم'), 'KG');
    });
  });

  group('writer side (offline reconciliation)', () {
    test('coded() stores the English render plus code and params', () {
      final d = CodedItemText.coded('details', 'DOC_CHK_INVOICE_NO_MISMATCH',
          {'document_value': 'INV-1', 'system_value': 'INV-2'});
      expect(d['details'],
          'Invoice number in the document (INV-1) differs from the system invoice number (INV-2)!');
      expect(d['details_code'], 'DOC_CHK_INVOICE_NO_MISMATCH');
      expect(d['details_params'], {'document_value': 'INV-1', 'system_value': 'INV-2'});
      // The stored row renders in Arabic from the code.
      final row = CodedItemText.localizeRow(d, ar, forExport: true);
      expect(row['details'], 'رقم الفاتورة بالمستند (INV-1) يختلف عن رقم الفاتورة بالسستم (INV-2)!');
    });

    test('finalize() mirrors the backend structured_values shapes', () {
      final item = CodedItemText.finalize({
        'system_value': const CodedMeasure(1234.5, 'KG'),
        'extracted_value': const CodedPlaceholder('NOT_IN_DOCUMENT'),
        'packages': const CodedMeasure(7, 'PACKAGES', decimals: null),
        'plain': 'text',
      });
      expect(item['system_value'], '1,234.50 kg');
      expect(item['extracted_value'], 'Not found in the document');
      expect(item['packages'], '7 packages');
      expect(item['plain'], 'text');
      expect(item['structured_values'], {
        'system_value': {'number': 1234.5, 'unit': 'KG'},
        'extracted_value': {'placeholder': 'NOT_IN_DOCUMENT'},
        'packages': {'number': 7, 'unit': 'PACKAGES'},
      });
      final ar = CodedItemText.localizeRow(item, const AppLocalizationsAr());
      expect(ar['extracted_value'], 'غير متوفر بالمستند');
      expect(ar['packages'], '7 طرد');
    });
  });

  group('Draft B/L models', () {
    test('matrix item keeps the code through JSON and renders per language', () {
      final item = DraftBLDiscrepancyItemModel.fromJson({
        'field_key': 'acid_number',
        'match_status': 'MISMATCH_CRITICAL',
        'system_value': 'A',
        'draft_value': 'B',
        'details': "Mismatch! System value: 'A' | Draft value: 'B'.",
        'details_code': 'DOC_DRAFT_VALUE_MISMATCH',
        'details_params': {'system_value': 'A', 'draft_value': 'B'},
      });
      expect(SystemMessageRenderer.stripIsolates(item.displayDetails(ar)), "عدم تطابق! قيمة النظام: 'A' | قيمة الدرافت: 'B'.");
      expect(item.displayDetails(en), "Mismatch! System value: 'A' | Draft value: 'B'.");
      final json = item.toJson();
      expect(json['details_code'], 'DOC_DRAFT_VALUE_MISMATCH');
      expect(json['details_params'], {'system_value': 'A', 'draft_value': 'B'});
    });

    test('legacy matrix item without a code shows its Arabic text', () {
      final item = DraftBLDiscrepancyItemModel.fromJson({
        'field_key': 'x',
        'details': 'مطابقة نصية تامة 100%.',
      });
      expect(item.detailsCode, isNull);
      expect(item.displayDetails(en), 'مطابقة نصية تامة 100%.');
    });

    test('checklist reason: code round-trips; a typed reason replaces it', () {
      final item = DraftBLChecklistItemModel.fromJson({
        'field_key': 'acid_number',
        'reason': 'Required field was not extracted or entered in the draft B/L data.',
        'reason_code': 'DOC_DRAFT_FIELD_MISSING',
        'reason_params': <String, dynamic>{},
      });
      expect(item.displayReason(ar), 'الحقل مطلوب ولم يتم استخراجه أو إدخاله في بيانات درافت البوليصة.');
      expect(item.displayReason(en), 'Required field was not extracted or entered in the draft B/L data.');
      expect(item.toJson()['reason_code'], 'DOC_DRAFT_FIELD_MISSING');

      // The tab clears the code when the user types a reason.
      item
        ..reason = 'Supplier will reissue'
        ..reasonCode = null
        ..reasonParams = null;
      expect(item.displayReason(ar), 'Supplier will reissue');
      expect(item.toJson()['reason_code'], isNull);
    });
  });

  group('customs category', () {
    CustomsTariffModel tariff(String? category) => CustomsTariffModel.fromJson({
          'tariff_id': 1,
          'hs_code': '8501',
          'hs_description': 'Motors',
          'customs_category': category,
        });

    test('code, legacy Arabic label and legacy English label display in the UI language', () {
      expect(tariff('MACHINERY_EQUIPMENT').categoryLabel(ar), 'آلات وأجهزة وتجهيزات');
      expect(tariff('MACHINERY_EQUIPMENT').categoryLabel(en), 'Machinery, appliances & equipment');
      expect(tariff('آلات وأجهزة وتجهيزات').categoryLabel(en), 'Machinery, appliances & equipment');
      expect(tariff('أصناف عامة').categoryLabel(en), 'General goods');
      expect(tariff('General').categoryLabel(ar), 'أصناف عامة');
    });

    test('unknown legacy text is shown as stored; empty is null', () {
      expect(tariff('Luxury Goods').categoryLabel(ar), 'Luxury Goods');
      expect(tariff(null).categoryLabel(ar), isNull);
      expect(tariff('  ').categoryLabel(ar), isNull);
    });

    test('search text covers the code and both labels', () {
      final text = tariff('MACHINERY_EQUIPMENT').categorySearchText;
      expect(text, contains('machinery_equipment'));
      expect(text, contains('machinery, appliances'));
      expect(text, contains('آلات'));
    });
  });
}
