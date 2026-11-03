import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../currencies/models/currency_model.dart';
import '../../../currencies/providers/currencies_provider.dart';
import '../../providers/customs_tariff_provider.dart';
import 'duty_calc_sample_data.dart';

/// Converts a dynamic value to a double with an optional fallback.
double numToDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? fallback;
  return fallback;
}

/// Reactive state holder and calculation engine for the Customs Duty Calculator.
class DutyCalculatorState extends ChangeNotifier {
  String selectedCurrency = 'USD';
  String selectedFreightCurrency = 'USD';

  final exchangeRateCtrl = TextEditingController();
  final totalInvoiceFcCtrl = TextEditingController();
  final insuranceCtrl = TextEditingController();
  final deemedInsuranceCtrl = TextEditingController();
  final freightForeignCtrl = TextEditingController();
  final freightExchangeRateCtrl = TextEditingController();
  final multiFreightCtrl = TextEditingController();
  final deemedFreightCtrl = TextEditingController();
  final additionalFeesCtrl = TextEditingController();
  final declaredCifCtrl = TextEditingController();

  String insuranceType = 'actual';
  String freightType = 'actual';

  List<Map<String, dynamic>> multiLines = [];
  Map<String, dynamic>? multiResult;
  String? multiError;
  bool isMultiCalculating = false;
  bool didAutoSimulate = false;
  bool didInitialRateLoad = false;

  DutyCalculatorState({
    String? initialHsCode,
    String? initialCurrency,
    double? initialFreightAmount,
    double? initialInsuranceAmount,
    List<Map<String, dynamic>>? initialExtractedLines,
  }) {
    if (initialCurrency != null && initialCurrency.trim().isNotEmpty) {
      selectedCurrency = initialCurrency.trim().toUpperCase();
    }
    selectedFreightCurrency = selectedCurrency;

    if (initialExtractedLines != null && initialExtractedLines.isNotEmpty) {
      multiLines = DutyCalcLineFactory.createLinesFromExtracted(initialExtractedLines);
      final sumVal = computeTotalInvoiceFc();
      if (sumVal > 0) totalInvoiceFcCtrl.text = sumVal.toStringAsFixed(2);
      if (initialFreightAmount != null && initialFreightAmount > 0) {
        freightForeignCtrl.text = initialFreightAmount.toStringAsFixed(2);
      }
      if (initialInsuranceAmount != null && initialInsuranceAmount > 0) {
        insuranceCtrl.text = initialInsuranceAmount.toStringAsFixed(2);
      }
    } else {
      multiLines = [DutyCalcLineFactory.createDefaultLine(initialHsCode)];
    }
  }

  double computeTotalInvoiceFc() {
    double total = 0;
    for (final m in multiLines) {
      final val = double.tryParse(
              (m['value'] as TextEditingController).text.trim()) ??
          0;
      total += val;
    }
    return total;
  }

  double computeTotalFobEgp() {
    final rate = double.tryParse(exchangeRateCtrl.text.trim()) ?? 0.0;
    return computeTotalInvoiceFc() * rate;
  }

  void recalcDeemedInsurance() {
    if (insuranceType != 'deemed') return;
    final deemed = computeTotalFobEgp() * 0.025;
    deemedInsuranceCtrl.text = deemed > 0 ? deemed.toStringAsFixed(3) : '';
    insuranceCtrl.text = '';
  }

  void recalcDeemedFreight() {
    if (freightType != 'deemed') return;
    final deemed = computeTotalFobEgp() * 0.020;
    deemedFreightCtrl.text = deemed > 0 ? deemed.toStringAsFixed(3) : '';
    multiFreightCtrl.text = '';
  }

  double get effectiveInsurance {
    final actual = double.tryParse(insuranceCtrl.text.trim()) ?? 0;
    final deemed = double.tryParse(deemedInsuranceCtrl.text.trim()) ?? 0;
    return insuranceType == 'deemed' ? deemed : actual;
  }

  double get effectiveFreight {
    final actual = double.tryParse(multiFreightCtrl.text.trim()) ?? 0;
    final deemed = double.tryParse(deemedFreightCtrl.text.trim()) ?? 0;
    return freightType == 'deemed' ? deemed : actual;
  }

  void syncCalculatedFields() {
    final totalFc = computeTotalInvoiceFc();
    final rate = double.tryParse(exchangeRateCtrl.text.trim()) ?? 0.0;
    final fobEgp = totalFc * rate;

    if (insuranceType == 'deemed') {
      recalcDeemedInsurance();
    }

    if (freightType == 'deemed') {
      recalcDeemedFreight();
    } else {
      final fAmt = double.tryParse(freightForeignCtrl.text.trim()) ?? 0;
      final customRate = double.tryParse(freightExchangeRateCtrl.text.trim());
      final fRate = selectedFreightCurrency == 'EGP'
          ? 1.0
          : (customRate ?? (selectedFreightCurrency == selectedCurrency ? rate : null));
      multiFreightCtrl.text =
          (fRate != null && fAmt > 0) ? (fAmt * fRate).toStringAsFixed(3) : '';
    }

    final calculatedCifEgp = fobEgp + effectiveInsurance + effectiveFreight;
    totalInvoiceFcCtrl.text = totalFc > 0 ? totalFc.toStringAsFixed(2) : '';
    declaredCifCtrl.text = calculatedCifEgp > 0 ? calculatedCifEgp.toStringAsFixed(2) : '';
    notifyListeners();
  }

  double? _getCurrencyCustomsRate(WidgetRef ref, String code) {
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final curr = currencies.cast<CurrencyModel?>().firstWhere(
      (c) => c != null && c.currencyCode.toUpperCase() == code.toUpperCase(),
      orElse: () => null,
    );
    return (curr != null && curr.latestCustomsRate != null && curr.latestCustomsRate! > 0)
        ? curr.latestCustomsRate
        : null;
  }

  void setSelectedCurrency(String val, WidgetRef ref) {
    selectedCurrency = val;
    if (freightType == 'actual' && selectedFreightCurrency == 'USD') {
      selectedFreightCurrency = val;
    }
    final rate = _getCurrencyCustomsRate(ref, val);
    exchangeRateCtrl.text = rate != null
        ? rate.toStringAsFixed(4)
        : (val == 'EGP' ? '1.0000' : '');
    syncCalculatedFields();
  }

  void setSelectedFreightCurrency(String val) {
    selectedFreightCurrency = val;
    freightExchangeRateCtrl.text = '';
    syncCalculatedFields();
  }

  void setInsuranceType(String type) {
    insuranceType = type;
    if (type == 'deemed') {
      insuranceCtrl.text = '';
      recalcDeemedInsurance();
    } else {
      deemedInsuranceCtrl.text = '';
    }
    syncCalculatedFields();
  }

  void setFreightType(String type) {
    freightType = type;
    if (type == 'deemed') {
      multiFreightCtrl.text = '';
      recalcDeemedFreight();
    } else {
      deemedFreightCtrl.text = '';
    }
    syncCalculatedFields();
  }

  void addLine() {
    multiLines.add(DutyCalcLineFactory.createDefaultLine());
    syncCalculatedFields();
  }

  void removeLine(int index) {
    if (index >= 0 && index < multiLines.length) {
      final m = multiLines.removeAt(index);
      (m['hs'] as TextEditingController?)?.dispose();
      (m['value'] as TextEditingController?)?.dispose();
      (m['inspection'] as TextEditingController?)?.dispose();
      syncCalculatedFields();
    }
  }

  void updateLineOrigin(int index, String? origin) {
    if (index >= 0 && index < multiLines.length) {
      multiLines[index]['origin'] = origin;
      notifyListeners();
    }
  }

  void updateLineExemption(int index, String? exemption) {
    if (index >= 0 && index < multiLines.length) {
      multiLines[index]['exemption'] = exemption;
      notifyListeners();
    }
  }

  void updateLineExemptionMet(int index, bool isMet) {
    if (index >= 0 && index < multiLines.length) {
      multiLines[index]['is_exemption_conditions_met'] = isMet;
      notifyListeners();
    }
  }

  void loadInitialRate(WidgetRef ref) {
    if (exchangeRateCtrl.text.isEmpty) {
      final rate = _getCurrencyCustomsRate(ref, selectedCurrency);
      if (rate != null) {
        exchangeRateCtrl.text = rate.toStringAsFixed(4);
        syncCalculatedFields();
      }
    }
  }

  void _disposeCurrentLines() {
    for (final m in multiLines) {
      (m['hs'] as TextEditingController?)?.dispose();
      (m['value'] as TextEditingController?)?.dispose();
      (m['inspection'] as TextEditingController?)?.dispose();
    }
  }

  void _applySimulationResult(Map<String, dynamic> res) {
    multiResult = res;
    if (res['currency_code'] != null) {
      selectedCurrency = res['currency_code'].toString();
    }
    if (res['exchange_rate'] != null) {
      exchangeRateCtrl.text = numToDouble(res['exchange_rate']).toStringAsFixed(4);
    }
    if (res['insurance_egp'] != null) {
      insuranceCtrl.text = numToDouble(res['insurance_egp']).toStringAsFixed(2);
    }
    if (res['insurance_source'] == 'deemed_2.5_percent') {
      insuranceType = 'deemed';
      deemedInsuranceCtrl.text = insuranceCtrl.text;
      insuranceCtrl.text = '0.00';
    } else {
      insuranceType = 'actual';
    }
    if (res['freight_egp'] != null) {
      multiFreightCtrl.text = numToDouble(res['freight_egp']).toStringAsFixed(2);
    }
    if (res['freight_source'] == 'deemed_2.0_percent') {
      freightType = 'deemed';
      deemedFreightCtrl.text = multiFreightCtrl.text;
      multiFreightCtrl.text = '0.00';
    } else {
      freightType = 'actual';
    }
    if (res['cif_base_egp'] != null) {
      declaredCifCtrl.text = numToDouble(res['cif_base_egp']).toStringAsFixed(2);
    }
    if (res['total_other_fees_egp'] != null) {
      additionalFeesCtrl.text =
          numToDouble(res['total_other_fees_egp']).toStringAsFixed(2);
    }

    final resLines = (res['lines'] as List<dynamic>?) ?? [];
    if (resLines.isNotEmpty) {
      _disposeCurrentLines();
      multiLines = resLines
          .map((l) => DutyCalcLineFactory.createFromSimulation(
              l as Map<String, dynamic>, numToDouble))
          .toList();
    }
    syncCalculatedFields();
  }

  Future<void> runImportFileSimulation(int fileId, WidgetRef ref) async {
    isMultiCalculating = true;
    multiError = null;
    notifyListeners();

    try {
      final res = await ref
          .read(customsTariffProvider.notifier)
          .simulateImportFileDuties(fileId);
      if (res != null) {
        _applySimulationResult(res);
      }
    } catch (e) {
      multiError = e.toString().replaceAll('Exception: ', '');
      multiResult = null;
    } finally {
      isMultiCalculating = false;
      notifyListeners();
    }
  }

  void loadNafezaSample(WidgetRef ref) {
    final rate = _getCurrencyCustomsRate(ref, 'USD');
    final dynamicRate = rate != null ? rate.toStringAsFixed(4) : '';

    selectedCurrency = DutyCalcSampleData.currency;
    selectedFreightCurrency = DutyCalcSampleData.currency;
    exchangeRateCtrl.text = dynamicRate;
    insuranceCtrl.text = DutyCalcSampleData.insuranceAmount;
    deemedInsuranceCtrl.text = '0.00';
    insuranceType = 'actual';
    freightForeignCtrl.text = DutyCalcSampleData.freightForeignAmount;
    multiFreightCtrl.text = DutyCalcSampleData.freightEgpAmount;
    deemedFreightCtrl.text = '0.00';
    freightType = 'actual';
    additionalFeesCtrl.text = DutyCalcSampleData.additionalFeesAmount;

    _disposeCurrentLines();
    multiLines = DutyCalcSampleData.buildSampleLines();
    syncCalculatedFields();
    notifyListeners();
  }

  List<Map<String, dynamic>> _buildLinesPayload() {
    return multiLines.asMap().entries.map((entry) {
      final i = entry.key;
      final m = entry.value;
      return {
        'line_no': i + 1,
        'hs_code': (m['hs'] as TextEditingController).text.trim(),
        'value_fc': double.tryParse((m['value'] as TextEditingController).text.trim()) ?? 0,
        'inspection_fee_egp':
            double.tryParse((m['inspection'] as TextEditingController).text.trim()) ?? 0,
        'origin_country': m['origin'],
        'exemption_code': m['exemption'],
        'is_exemption_conditions_met': m['is_exemption_conditions_met'] == true,
      };
    }).toList();
  }

  Map<String, dynamic> _buildPayload(
    double rate,
    double actualIns,
    double actualFrt,
    double add,
    double? decCif,
    List<Map<String, dynamic>> linesData,
  ) {
    final customRate = double.tryParse(freightExchangeRateCtrl.text.trim());
    return {
      'currency': selectedCurrency,
      'exchange_rate': rate,
      'insurance_egp': actualIns,
      'freight_egp': actualFrt,
      'freight_currency': selectedFreightCurrency,
      'freight_foreign_amount':
          double.tryParse(freightForeignCtrl.text.trim()) ?? 0,
      if (customRate != null && customRate > 0)
        'freight_exchange_rate': customRate,
      'has_insurance_document': insuranceType != 'deemed',
      'has_freight_document': freightType != 'deemed',
      'additional_fees_egp': add,
      if (decCif != null && decCif > 0) 'cif_declared_total_egp': decCif,
      'lines': linesData,
    };
  }

  Future<void> calculateDuties(WidgetRef ref, {required bool isArabic}) async {
    final rate = double.tryParse(exchangeRateCtrl.text.trim()) ?? 0.0;
    if (rate <= 0) {
      multiError = isArabic
          ? 'يرجى إدخال أو اختيار سعر تحويل صحيح للعملة أولاً'
          : 'Please enter or select a valid exchange rate first';
      notifyListeners();
      return;
    }

    final double actualIns = (insuranceType == 'deemed')
        ? 0.0
        : (double.tryParse(insuranceCtrl.text.trim()) ?? 0);
    final double actualFrt = (freightType == 'deemed')
        ? 0.0
        : (double.tryParse(multiFreightCtrl.text.trim()) ?? 0);
    final add = double.tryParse(additionalFeesCtrl.text.trim()) ?? 0;
    final decCif = double.tryParse(declaredCifCtrl.text.trim());

    final linesData = _buildLinesPayload();
    if (linesData.isEmpty ||
        linesData.any((l) =>
            (l['hs_code'] as String).isEmpty || (l['value_fc'] as double) <= 0)) {
      multiError = isArabic
          ? 'يرجى إدخال بند جمركي وقيمة صالحة أكبر من صفر لكل صنف'
          : 'Please enter a valid HS code and value greater than 0 for all items';
      notifyListeners();
      return;
    }

    isMultiCalculating = true;
    multiError = null;
    notifyListeners();

    try {
      final payload = _buildPayload(rate, actualIns, actualFrt, add, decCif, linesData);
      multiResult = await ref
          .read(customsTariffProvider.notifier)
          .estimateMultiItemDuty(payload);
    } catch (e) {
      multiError = e.toString().replaceAll('Exception: ', '');
      multiResult = null;
    } finally {
      isMultiCalculating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    exchangeRateCtrl.dispose();
    totalInvoiceFcCtrl.dispose();
    insuranceCtrl.dispose();
    deemedInsuranceCtrl.dispose();
    freightForeignCtrl.dispose();
    freightExchangeRateCtrl.dispose();
    multiFreightCtrl.dispose();
    deemedFreightCtrl.dispose();
    additionalFeesCtrl.dispose();
    declaredCifCtrl.dispose();
    _disposeCurrentLines();
    super.dispose();
  }
}
