import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/system_messages/system_message_renderer.dart';
import 'package:frontend/core/services/master_data_export_service.dart';
import 'package:frontend/core/utils/app_format.dart';
import 'package:frontend/features/external_service_providers/widgets/partner_statement_of_account_dialog.dart';

void main() {
  group('AppFormat.number', () {
    test('groups thousands with fixed decimals', () {
      expect(AppFormat.number(1234567.891), '1,234,567.89');
      expect(AppFormat.number(0), '0.00');
      expect(AppFormat.number(999), '999.00');
      expect(AppFormat.number(1000), '1,000.00');
    });

    test('rounds half away from zero', () {
      expect(AppFormat.number(2.345), '2.35');
      expect(AppFormat.number(-2.345), '-2.35');
      expect(AppFormat.number(0.5, decimals: 0), '1');
    });

    test('supports custom decimals and trimZeros', () {
      expect(AppFormat.number(1.23456, decimals: 4), '1.2346');
      expect(AppFormat.number(1234.5, trimZeros: true), '1,234.5');
      expect(AppFormat.number(1000, trimZeros: true), '1,000');
      expect(AppFormat.number(12.3456, decimals: 0), '12');
    });

    test('negatives keep the sign, negative zero does not', () {
      expect(AppFormat.number(-1234.5), '-1,234.50');
      expect(AppFormat.number(-0.001), '0.00');
    });

    test('null uses fallback, non-finite uses toString', () {
      expect(AppFormat.number(null), '-');
      expect(AppFormat.number(null, fallback: ''), '');
      expect(AppFormat.number(double.nan), 'NaN');
      expect(AppFormat.number(double.infinity), 'Infinity');
    });

    test('integer()', () {
      expect(AppFormat.integer(12500), '12,500');
      expect(AppFormat.integer(12500.6), '12,501');
      expect(AppFormat.integer(null), '-');
    });
  });

  group('AppFormat.money / percent', () {
    test('money appends the currency code', () {
      expect(AppFormat.money(623000, currency: 'EGP'), '623,000.00 EGP');
      expect(AppFormat.money(1234.5, currency: ' USD '), '1,234.50 USD');
      expect(AppFormat.money(1234.5), '1,234.50');
      expect(AppFormat.money(1234.5, currency: ''), '1,234.50');
      expect(AppFormat.money(10, currency: 'JPY', decimals: 0), '10 JPY');
      expect(AppFormat.money(null, currency: 'EGP'), '-');
    });

    test('percent trims trailing zeros', () {
      expect(AppFormat.percent(14), '14%');
      expect(AppFormat.percent(12.5), '12.5%');
      expect(AppFormat.percent(null), '-');
    });
  });

  group('AppFormat.date / dateTime', () {
    test('formats DateTime values', () {
      final dt = DateTime(2026, 3, 7, 9, 5);
      expect(AppFormat.date(dt), '2026-03-07');
      expect(AppFormat.dateTime(dt), '2026-03-07 09:05');
    });

    test('parses ISO strings', () {
      expect(AppFormat.date('2026-11-12T10:20:30'), '2026-11-12');
      expect(AppFormat.dateTime('2026-11-12T10:20:30'), '2026-11-12 10:20');
    });

    test('empty-ish input renders the fallback', () {
      for (final v in [null, '', '  ', 'null', '-']) {
        expect(AppFormat.date(v), '-', reason: 'input: $v');
      }
      expect(AppFormat.date(null, fallback: 'N/A'), 'N/A');
    });

    test('unparsable text is kept so legacy free-text dates are not lost', () {
      expect(AppFormat.date('Q3 2026'), 'Q3 2026');
    });

    test('parseDate', () {
      expect(AppFormat.parseDate('2026-01-02'), DateTime(2026, 1, 2));
      expect(AppFormat.parseDate('nope'), isNull);
      expect(AppFormat.parseDate(null), isNull);
    });
  });

  group('Legacy helpers delegate to AppFormat (behaviour preserved)', () {
    test('MasterDataExportService.formatDateSafe', () {
      expect(MasterDataExportService.formatDateSafe(DateTime(2026, 1, 9)), '2026-01-09');
      expect(MasterDataExportService.formatDateSafe('2026-01-09T08:00:00'), '2026-01-09');
      expect(MasterDataExportService.formatDateSafe(null), '-');
      expect(MasterDataExportService.formatDateSafe('null'), '-');
    });

    test('SystemMessageRenderer.formatNumber', () {
      expect(SystemMessageRenderer.formatNumber(1234567.5), '1,234,567.5');
      expect(SystemMessageRenderer.formatNumber(12.345), '12.35');
      expect(SystemMessageRenderer.formatNumber(-1000), '-1,000');
    });

    test('PartnerStatementOfAccountDialog.formatNumber', () {
      expect(PartnerStatementOfAccountDialog.formatNumber(1234567.891), '1,234,567.89');
      expect(PartnerStatementOfAccountDialog.formatNumber(-1500), '-1,500.00');
      expect(PartnerStatementOfAccountDialog.formatNumber(0), '0.00');
    });
  });
}
