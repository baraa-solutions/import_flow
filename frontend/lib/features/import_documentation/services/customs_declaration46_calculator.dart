import '../../currencies/models/currency_model.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../freight_booking/models/freight_booking_model.dart';
import '../../import_files/models/import_file_model.dart';

/// Result of the Form 46 customs assessment for one import file (Column A / Initial Study).
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

/// Result of the updated customs figures (Column B / Revised Estimate).
///
/// Calculated using actual booking freight and revised exchange rates:
/// Revised_CIF = (FOB USD + Booking Freight USD) * Exchange Rate + Insurance EGP + Unloading EGP
class Form46RevisedFigures {
  final double? fobUsd;
  final double? freightUsd;
  final double? exchangeRate;
  final double? fobEgp;
  final double? freightEgp;
  final double? insuranceEgp;
  final double? unloadingEgp;
  final double? extraFeesEgp;
  final double? cifEgp;
  final double? dutyRate;
  final double? importDutyEgp;
  final double? atsRate; // 1% أ.ت.ص
  final double? atsEgp;
  final double? vatRate; // 14%
  final double? vatBaseEgp;
  final double? vatEgp;
  final double? devFeeRate;
  final double? devFeeEgp;
  final double? totalDutiesEgp;
  final String? estimateDate;
  final String? notes;
  final List<String> missing;

  const Form46RevisedFigures({
    this.fobUsd,
    this.freightUsd,
    this.exchangeRate,
    this.fobEgp,
    this.freightEgp,
    this.insuranceEgp = 0.0,
    this.unloadingEgp = 0.0,
    this.extraFeesEgp = 0.0,
    this.cifEgp,
    this.dutyRate,
    this.importDutyEgp,
    this.atsRate = 1.0,
    this.atsEgp,
    this.vatRate = 14.0,
    this.vatBaseEgp,
    this.vatEgp,
    this.devFeeRate,
    this.devFeeEgp,
    this.totalDutiesEgp,
    this.estimateDate,
    this.notes,
    this.missing = const [],
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

  /// Compute Column A (Original Study) customs figures.
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

    double rnd(double v) => (v * 100).roundToDouble() / 100;
    final fob = (fobForeign != null && fobForeign > 0) ? fobForeign : null;
    final fobEgp = (fob != null && customsFxRate != null) ? rnd(fob * customsFxRate) : null;
    final cif = fobEgp; // freight / insurance are not recorded: see flag

    final dutyRate = tariff?.customsDutyRate;
    final vatRate = tariff?.vatRate;
    final devRate = tariff?.developmentFeeRate;
    final serviceRate = tariff?.customsServiceFeeRate;

    // Mirrors modules/customs_tariff/service.py: every component is rounded to
    // 2 decimals; VAT base = CIF + import duty only.
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

  /// Compute Column B (Revised Estimate) figures with booking freight, updated rates,
  /// and explicit Egyptian customs CIF base formula:
  ///
  /// Revised_CIF = (FOB USD + Booking Freight USD) * Exchange Rate + Insurance EGP + Unloading EGP
  ///
  /// Import Duty = CIF * Tariff Duty %
  /// أ.ت.ص = CIF * 1% (Commercial & Industrial Profits Tax / Service Fee)
  /// VAT Base = CIF + Import Duty + أ.ت.ص
  /// VAT = VAT Base * 14%
  /// Total Duties = Import Duty + VAT + أ.ت.ص + Extra Fees
  static Form46RevisedFigures calculateRevisedFigures({
    required double? fobUsd,
    required double? exchangeRate,
    ShipmentBookingModel? booking,
    double? bookingFreightUsd,
    double insuranceEgp = 0.0,
    double unloadingEgp = 0.0,
    double extraFeesEgp = 0.0,
    CustomsTariffModel? tariff,
    double? dutyRateOverride,
    double? vatRateOverride,
    double? atsRateOverride,
    String? estimateDate,
    String? notes,
  }) {
    final freightUsd = bookingFreightUsd ?? booking?.totalFreightCostUsd ?? 0.0;
    final missing = <String>[
      if (fobUsd == null || fobUsd <= 0) 'fob_usd',
      if (exchangeRate == null || exchangeRate <= 0) 'fx_rate',
      if (tariff == null && dutyRateOverride == null) 'tariff',
    ];

    double rnd(double v) => (v * 100).roundToDouble() / 100;

    if (fobUsd == null || fobUsd <= 0 || exchangeRate == null || exchangeRate <= 0 ||
        (tariff == null && dutyRateOverride == null)) {
      return Form46RevisedFigures(
        fobUsd: fobUsd,
        freightUsd: freightUsd,
        exchangeRate: exchangeRate,
        insuranceEgp: insuranceEgp,
        unloadingEgp: unloadingEgp,
        extraFeesEgp: extraFeesEgp,
        estimateDate: estimateDate,
        notes: notes,
        missing: missing,
      );
    }

    final fobEgp = rnd(fobUsd * exchangeRate);
    final freightEgp = rnd(freightUsd * exchangeRate);

    // Revised_CIF = (FOB USD + Booking Freight USD) * Exchange Rate + Insurance EGP + Unloading EGP
    final cifEgp = rnd((fobUsd + freightUsd) * exchangeRate + insuranceEgp + unloadingEgp);

    final dutyRate = dutyRateOverride ?? tariff?.customsDutyRate ?? 0.0;
    final importDutyEgp = rnd(cifEgp * (dutyRate / 100.0));

    // أ.ت.ص = 1% on CIF
    final atsRate = atsRateOverride ?? 1.0;
    final atsEgp = rnd(cifEgp * (atsRate / 100.0));

    // VAT Base = CIF + Import Duty + أ.ت.ص
    final vatBaseEgp = rnd(cifEgp + importDutyEgp + atsEgp);
    final vatRate = vatRateOverride ?? tariff?.vatRate ?? 14.0;
    final vatEgp = rnd(vatBaseEgp * (vatRate / 100.0));

    final extra = rnd(extraFeesEgp);
    // Total duties = Import Duty + VAT + أ.ت.ص + extra fees
    final totalDutiesEgp = rnd(importDutyEgp + vatEgp + atsEgp + extra);

    return Form46RevisedFigures(
      fobUsd: fobUsd,
      freightUsd: freightUsd,
      exchangeRate: exchangeRate,
      fobEgp: fobEgp,
      freightEgp: freightEgp,
      insuranceEgp: insuranceEgp,
      unloadingEgp: unloadingEgp,
      extraFeesEgp: extra,
      cifEgp: cifEgp,
      dutyRate: dutyRate,
      importDutyEgp: importDutyEgp,
      atsRate: atsRate,
      atsEgp: atsEgp,
      vatRate: vatRate,
      vatBaseEgp: vatBaseEgp,
      vatEgp: vatEgp,
      devFeeRate: atsRate,
      devFeeEgp: atsEgp,
      totalDutiesEgp: totalDutiesEgp,
      estimateDate: estimateDate,
      notes: notes,
      missing: const [],
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
