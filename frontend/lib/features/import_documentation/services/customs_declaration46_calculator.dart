import '../../currencies/models/currency_model.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../import_files/models/import_file_model.dart';

/// Result of the Form 46 customs assessment for one import file.
///
/// Every figure is nullable: a figure is null when one of its inputs is not
/// available from the backend (tariff row, customs exchange rate, FOB value).
/// No fallback rate or amount is ever invented; callers render null as
/// "missing" and must not export it as a number.
class Form46Figures {
  final double? fobForeign;
  final double? exchangeRate;
  final double? fobEgp;
  final double? cifEgp;
  final double? dutyRate;
  final double? importDutyEgp;
  final double? devRate;
  final double? devFeeEgp;
  final double? serviceRate;
  final double? serviceFeeEgp;
  final double? otherFeesEgp;
  final double? vatRate;
  final double? scheduleTaxRate;
  final double? scheduleTaxEgp;
  final double? importFeeRate;
  final double? importFeeEgp;
  final double? vatBaseEgp;
  final double? vatEgp;
  final double? totalDutiesEgp;
  final bool hasExemption;

  /// Missing inputs: any of `tariff`, `fx_rate`, `fob`.
  final List<String> missing;

  /// Freight and insurance amounts are not recorded on the import file, so
  /// the customs value (CIF) above only contains FOB.
  final bool cifExcludesFreightInsurance;

  const Form46Figures({
    this.fobForeign,
    this.exchangeRate,
    this.fobEgp,
    this.cifEgp,
    this.dutyRate,
    this.importDutyEgp,
    this.devRate,
    this.devFeeEgp,
    this.serviceRate,
    this.serviceFeeEgp,
    this.otherFeesEgp,
    this.vatRate,
    this.scheduleTaxRate,
    this.scheduleTaxEgp,
    this.importFeeRate,
    this.importFeeEgp,
    this.vatBaseEgp,
    this.vatEgp,
    this.totalDutiesEgp,
    this.hasExemption = false,
    this.missing = const [],
    this.cifExcludesFreightInsurance = true,
  });

  bool get isComplete => missing.isEmpty;
}

/// FOB taken from the invoices of an import file (never from estimated cost).
class Form46Fob {
  final double? amount;
  final String currency;

  /// null when resolved; `no_invoices` or `mixed_currency` otherwise.
  final String? issue;
  const Form46Fob({this.amount, this.currency = '', this.issue});
}

/// Pure, testable Form 46 math. Rates come only from the backend tariff row
/// and the backend customs exchange rate.
class Form46Calculator {
  Form46Calculator._();

  /// Customs exchange rate (EGP per 1 unit of [currencyCode]) from the
  /// currencies master data, or null when it is not configured.
  /// EGP itself is 1.0 by definition.
  static double? customsRateFor(String? currencyCode, List<CurrencyModel> currencies) {
    final code = (currencyCode ?? '').trim().toUpperCase();
    if (code.isEmpty) return null;
    if (code == 'EGP') return 1.0;
    for (final c in currencies) {
      if (c.currencyCode.toUpperCase() == code) {
        final r = c.latestCustomsRate;
        return (r != null && r > 0) ? r : null;
      }
    }
    return null;
  }

  /// Total of the form's component fields; empty when ANY component is empty
  /// or not a number (a missing component is never treated as 0).
  static String totalOfComponents(List<String> components) {
    double sum = 0;
    for (final c in components) {
      final v = double.tryParse(c.trim());
      if (v == null) return '';
      sum += v;
    }
    return sum.toStringAsFixed(2);
  }

  static String _digits(String v) => v.replaceAll(RegExp(r'[^0-9]'), '');

  /// Active tariff rows whose HS code equals one of [fileHsCodes] exactly
  /// (digits only, no substring match) and that are effective on [onDate].
  /// Newest `effectiveFrom` first.
  static List<CustomsTariffModel> matchTariffs(
    List<String> fileHsCodes,
    List<CustomsTariffModel> tariffs, {
    DateTime? onDate,
  }) {
    final codes = fileHsCodes.map(_digits).where((c) => c.isNotEmpty).toSet();
    if (codes.isEmpty) return const [];
    final d = onDate ?? DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final out = tariffs.where((t) {
      if (!t.isActive) return false;
      if (!codes.contains(_digits(t.hsCode))) return false;
      if (t.effectiveFrom.isAfter(day)) return false;
      final to = t.effectiveTo;
      if (to != null && DateTime(to.year, to.month, to.day).isBefore(day)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    return out;
  }

  /// Best tariff row (exact HS match, effective today); null when none
  /// (never falls back to an arbitrary tariff).
  static CustomsTariffModel? matchTariff(
    List<String> fileHsCodes,
    List<CustomsTariffModel> tariffs, {
    DateTime? onDate,
  }) {
    final m = matchTariffs(fileHsCodes, tariffs, onDate: onDate);
    return m.isEmpty ? null : m.first;
  }

  /// FOB = sum of the invoice amounts, only when every invoice shares one
  /// currency. `estimated_cost` (a landed-cost estimate) is never used.
  static Form46Fob invoiceFob(List<InvoiceItemModel> invoices) {
    final valid = invoices.where((i) => i.amount > 0).toList();
    if (valid.isEmpty) return const Form46Fob(issue: 'no_invoices');
    final currencies = valid.map((i) => i.currency.trim().toUpperCase()).toSet();
    if (currencies.length != 1 || currencies.first.isEmpty) {
      return const Form46Fob(issue: 'mixed_currency');
    }
    final total = valid.fold<double>(0.0, (t, i) => t + i.amount);
    return Form46Fob(amount: total, currency: currencies.first);
  }

  static Form46Figures compute({
    required double? fobForeign,
    required double? customsFxRate,
    required CustomsTariffModel? tariff,
    String? fobIssue,
  }) {
    final missing = <String>[
      if (tariff == null) 'tariff',
      if (customsFxRate == null) 'fx_rate',
      if (fobForeign == null || fobForeign <= 0)
        (fobIssue == 'mixed_currency' ? 'fob_mixed_currency' : 'fob'),
    ];

    final fob = (fobForeign != null && fobForeign > 0) ? fobForeign : null;
    final fobEgp = (fob != null && customsFxRate != null) ? fob * customsFxRate : null;
    final cif = fobEgp; // freight / insurance are not recorded: see flag

    final dutyRate = tariff?.customsDutyRate;
    final vatRate = tariff?.vatRate;
    final devRate = tariff?.developmentFeeRate;
    final serviceRate = tariff?.customsServiceFeeRate;

    // Mirrors modules/customs_tariff/service.py: every component is rounded to
    // 2 decimals; VAT base = CIF + import duty only.
    double rnd(double v) => (v * 100).roundToDouble() / 100;
    double? importDuty, devFee, serviceFee, scheduleTax, importFee, other, vatBase, vat, total;
    if (cif != null && tariff != null) {
      importDuty = rnd(cif * (dutyRate! / 100.0));
      scheduleTax = rnd(cif * (tariff.scheduleTaxRate / 100.0));
      devFee = rnd(cif * (devRate! / 100.0));
      importFee = rnd(cif * (tariff.importFeeRate / 100.0));
      serviceFee = rnd(cif * (serviceRate! / 100.0));
      other = rnd(scheduleTax + devFee + importFee + serviceFee);
      vatBase = cif + importDuty;
      vat = rnd(vatBase * (vatRate! / 100.0));
      total = rnd(importDuty + vat + scheduleTax + devFee + importFee + serviceFee);
    }

    return Form46Figures(
      fobForeign: fob,
      exchangeRate: customsFxRate,
      fobEgp: fobEgp,
      cifEgp: cif,
      dutyRate: dutyRate,
      importDutyEgp: importDuty,
      devRate: devRate,
      devFeeEgp: devFee,
      serviceRate: serviceRate,
      serviceFeeEgp: serviceFee,
      otherFeesEgp: other,
      vatRate: vatRate,
      scheduleTaxRate: tariff?.scheduleTaxRate,
      scheduleTaxEgp: scheduleTax,
      importFeeRate: tariff?.importFeeRate,
      importFeeEgp: importFee,
      vatBaseEgp: vatBase,
      vatEgp: vat,
      totalDutiesEgp: total,
      // Exemption only when the tariff itself says duty is 0.
      hasExemption: dutyRate != null && dutyRate == 0.0,
      missing: missing,
    );
  }
}

/// Formatting for figures that may be missing.
extension Form46NumFormat on double? {
  /// `toStringAsFixed(digits)`, or [missing] (default an em dash) when null.
  String fixedOrMissing(int digits, [String missing = '—']) =>
      this == null ? missing : this!.toStringAsFixed(digits);

  /// `12.34 EGP`, or [missing] when null (no dangling currency suffix).
  String egpOrMissing(String missing) => this == null ? missing : '${this!.toStringAsFixed(2)} EGP';
}
