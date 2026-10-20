import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/import_documentation/services/customs_declaration46_calculator.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

CustomsTariffModel _tariff({
  String hs = '8471.30.00',
  double duty = 10.0,
  double vat = 14.0,
  double dev = 1.0,
  double service = 2.0,
  double schedule = 3.0,
  double importFee = 4.0,
  String from = '2026-01-01',
  String? to,
  bool active = true,
}) {
  return CustomsTariffModel.fromJson({
    'tariff_id': 1,
    'hs_code': hs,
    'hs_description': 'x',
    'customs_duty_rate': duty,
    'vat_rate': vat,
    'schedule_tax_rate': schedule,
    'development_fee_rate': dev,
    'import_fee_rate': importFee,
    'customs_service_fee_rate': service,
    'effective_from': from,
    if (to != null) 'effective_to': to,
    'is_active': active,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
  });
}

CurrencyModel _cur(String code, double? customs) => CurrencyModel(
      currencyCode: code,
      currencyName: code,
      currencySymbol: code,
      latestCustomsRate: customs,
    );

void main() {
  invoiceFobTests();
  group('Form46Calculator: no client-side fallback rates', () {
    test('missing tariff -> no duty, VAT or fee numbers (no 5/14/1 percent fallback)', () {
      final f = Form46Calculator.compute(fobForeign: 1000, customsFxRate: 50.0, tariff: null);
      expect(f.missing, contains('tariff'));
      expect(f.isComplete, isFalse);
      expect(f.dutyRate, isNull);
      expect(f.vatRate, isNull);
      expect(f.serviceRate, isNull);
      expect(f.importDutyEgp, isNull);
      expect(f.vatEgp, isNull);
      expect(f.totalDutiesEgp, isNull);
      expect(f.hasExemption, isFalse);
    });

    test('missing customs FX rate -> no EGP figures (no 50.7917 fallback)', () {
      final f = Form46Calculator.compute(fobForeign: 1000, customsFxRate: null, tariff: _tariff());
      expect(f.missing, contains('fx_rate'));
      expect(f.fobEgp, isNull);
      expect(f.cifEgp, isNull);
      expect(f.totalDutiesEgp, isNull);
    });

    test('missing FOB -> flagged, no 12500 fallback', () {
      for (final fob in <double?>[null, 0, -5]) {
        final f = Form46Calculator.compute(fobForeign: fob, customsFxRate: 50.0, tariff: _tariff());
        expect(f.missing, contains('fob'));
        expect(f.fobEgp, isNull);
        expect(f.totalDutiesEgp, isNull);
      }
    });

    test('all inputs present: uses backend rates only, freight/insurance not invented', () {
      final f = Form46Calculator.compute(fobForeign: 1000, customsFxRate: 50.0, tariff: _tariff());
      expect(f.isComplete, isTrue);
      expect(f.fobEgp, 50000.0);
      expect(f.cifEgp, 50000.0); // no 2% freight / 2.5% insurance added
      expect(f.cifExcludesFreightInsurance, isTrue);
      expect(f.importDutyEgp, closeTo(5000.0, 1e-9));
      // dev 1% + service 2% + schedule 3% + import fee 4%
      expect(f.otherFeesEgp, closeTo(50000.0 * 0.10, 1e-9));
      expect(f.scheduleTaxEgp, closeTo(1500.0, 1e-9));
      expect(f.importFeeEgp, closeTo(2000.0, 1e-9));
      // VAT base = CIF + import duty ONLY (not fees)
      expect(f.vatBaseEgp, closeTo(55000.0, 1e-9));
      expect(f.vatEgp, closeTo(55000.0 * 0.14, 1e-9));
      expect(f.totalDutiesEgp, closeTo(5000.0 + 55000.0 * 0.14 + 5000.0, 1e-9));
    });

    test('exemption only when the tariff duty is 0 (no port-name guess)', () {
      final zero = Form46Calculator.compute(fobForeign: 100, customsFxRate: 50, tariff: _tariff(duty: 0));
      expect(zero.hasExemption, isTrue);
      final ten = Form46Calculator.compute(fobForeign: 100, customsFxRate: 50, tariff: _tariff(duty: 10));
      expect(ten.hasExemption, isFalse);
    });
  });

  group('Form46Calculator lookups', () {
    test('customsRateFor: configured, missing, zero, EGP', () {
      final list = [_cur('USD', 48.5), _cur('EUR', null), _cur('GBP', 0)];
      expect(Form46Calculator.customsRateFor('usd', list), 48.5);
      expect(Form46Calculator.customsRateFor('EUR', list), isNull);
      expect(Form46Calculator.customsRateFor('GBP', list), isNull);
      expect(Form46Calculator.customsRateFor('JPY', list), isNull);
      expect(Form46Calculator.customsRateFor('', list), isNull);
      expect(Form46Calculator.customsRateFor(null, list), isNull);
      expect(Form46Calculator.customsRateFor('EGP', const []), 1.0);
    });

    test('matchTariff never falls back to an arbitrary tariff', () {
      final tariffs = [_tariff(hs: '8471.30.00')];
      expect(Form46Calculator.matchTariff(const [], tariffs), isNull);
      expect(Form46Calculator.matchTariff(['9999.99.99'], tariffs), isNull);
      expect(Form46Calculator.matchTariff(['8471.30.00'], tariffs)?.hsCode, '8471.30.00');
    });

    test('exact HS match only: no substring match in either direction', () {
      final tariffs = [_tariff(hs: '8471.30.00')];
      expect(Form46Calculator.matchTariff(['8471'], tariffs), isNull);
      expect(Form46Calculator.matchTariff(['8471.30.00.10'], tariffs), isNull);
      expect(Form46Calculator.matchTariff(['847130'], tariffs), isNull);
      expect(Form46Calculator.matchTariff(['84713000'], tariffs)?.hsCode, '8471.30.00');
    });

    test('effective-date and active filters; newest effective row wins', () {
      final old = _tariff(duty: 5, from: '2020-01-01', to: '2024-12-31');
      final current = _tariff(duty: 10, from: '2025-01-01');
      final future = _tariff(duty: 99, from: '2999-01-01');
      final inactive = _tariff(duty: 77, from: '2025-06-01', active: false);
      final m = Form46Calculator.matchTariff(['8471.30.00'], [old, future, inactive, current]);
      expect(m?.customsDutyRate, 10.0);
      expect(Form46Calculator.matchTariff(['8471.30.00'], [old, future, inactive]), isNull);
      expect(
        Form46Calculator.matchTariff(['8471.30.00'], [old, current], onDate: DateTime(2023, 6, 1))?.customsDutyRate,
        5.0,
      );
    });
  });

  group('Form46Calculator.totalOfComponents', () {
    test('sums complete components', () {
      expect(Form46Calculator.totalOfComponents(['10.00', '5.50', '1']), '16.50');
    });
    test('any empty or invalid component leaves the total empty (never 0)', () {
      expect(Form46Calculator.totalOfComponents(['10', '', '1']), '');
      expect(Form46Calculator.totalOfComponents(['10', 'abc', '1']), '');
      expect(Form46Calculator.totalOfComponents(['', '', '']), '');
    });
  });

  group('Form46NumFormat', () {
    test('null renders as the missing marker, numbers as fixed', () {
      const double? none = null;
      expect(none.fixedOrMissing(2, 'Missing'), 'Missing');
      expect(none.egpOrMissing('Missing'), 'Missing');
      const double v = 12.345;
      expect(v.fixedOrMissing(2), '12.35');
      expect(v.egpOrMissing('Missing'), '12.35 EGP');
    });
  });
}

void invoiceFobTests() {
  InvoiceItemModel inv(double amount, String cur) => InvoiceItemModel(invoiceNo: 'I', amount: amount, currency: cur);

  group('Form46Calculator.invoiceFob', () {
    test('sums invoices of a single currency', () {
      final r = Form46Calculator.invoiceFob([inv(100, 'USD'), inv(50, 'usd')]);
      expect(r.amount, 150.0);
      expect(r.currency, 'USD');
      expect(r.issue, isNull);
    });

    test('mixed currencies -> missing with reason', () {
      final r = Form46Calculator.invoiceFob([inv(100, 'USD'), inv(50, 'EUR')]);
      expect(r.amount, isNull);
      expect(r.issue, 'mixed_currency');
      final f = Form46Calculator.compute(fobForeign: r.amount, fobIssue: r.issue, customsFxRate: 50, tariff: null);
      expect(f.missing, contains('fob_mixed_currency'));
      expect(f.missing, isNot(contains('fob')));
    });

    test('no invoices -> missing (estimated cost is never used)', () {
      final r = Form46Calculator.invoiceFob(const []);
      expect(r.amount, isNull);
      expect(r.issue, 'no_invoices');
      expect(Form46Calculator.invoiceFob([inv(0, 'USD')]).amount, isNull);
    });
  });
}
