import '../services/customs_pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/customs_tariff_model.dart';
import '../providers/customs_tariff_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../../currencies/models/currency_model.dart';
import '../../currencies/providers/currencies_provider.dart';

  void showDutyCalculatorDialog(BuildContext context, WidgetRef ref, {
    String? initialHsCode,
    int? initialImportFileId,
    String? initialCurrency,
    double? initialFreightAmount,
    double? initialInsuranceAmount,
    List<Map<String, dynamic>>? initialExtractedLines,
  }) {
    String selectedCurrency = (initialCurrency != null && initialCurrency.trim().isNotEmpty)
        ? initialCurrency.trim().toUpperCase()
        : 'USD';
    String selectedFreightCurrency = selectedCurrency;

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

    double computeTotalInvoiceFc(List<Map<String, dynamic>> lines) {
      double total = 0;
      for (final m in lines) {
        final val = double.tryParse(
                (m['value'] as TextEditingController).text.trim()) ??
            0;
        total += val;
      }
      return total;
    }

    double computeTotalFobEgp(List<Map<String, dynamic>> lines) {
      final rate = double.tryParse(exchangeRateCtrl.text.trim()) ?? 0.0;
      return computeTotalInvoiceFc(lines) * rate;
    }

    void recalcDeemedInsurance(
        StateSetter setState, List<Map<String, dynamic>> lines) {
      if (insuranceType != 'deemed') return;
      final deemed = computeTotalFobEgp(lines) * 0.025;
      setState(() {
        deemedInsuranceCtrl.text = deemed > 0 ? deemed.toStringAsFixed(3) : '';
        insuranceCtrl.text = '';
      });
    }

    void recalcDeemedFreight(
        StateSetter setState, List<Map<String, dynamic>> lines) {
      if (freightType != 'deemed') return;
      final deemed = computeTotalFobEgp(lines) * 0.020;
      setState(() {
        deemedFreightCtrl.text = deemed > 0 ? deemed.toStringAsFixed(3) : '';
        multiFreightCtrl.text = '';
      });
    }

    void syncCalculatedFields(
        StateSetter setState, List<Map<String, dynamic>> lines) {
      final totalFc = computeTotalInvoiceFc(lines);
      final rate = double.tryParse(exchangeRateCtrl.text.trim()) ?? 0.0;
      final fobEgp = totalFc * rate;

      if (insuranceType == 'deemed') {
        final deemedIns = fobEgp * 0.025;
        deemedInsuranceCtrl.text = deemedIns > 0 ? deemedIns.toStringAsFixed(3) : '';
        insuranceCtrl.text = '';
      }

      if (freightType == 'deemed') {
        final deemedFrt = fobEgp * 0.020;
        deemedFreightCtrl.text = deemedFrt > 0 ? deemedFrt.toStringAsFixed(3) : '';
        multiFreightCtrl.text = '';
      } else {
        final fAmt = double.tryParse(freightForeignCtrl.text.trim()) ?? 0;
        final customRate = double.tryParse(freightExchangeRateCtrl.text.trim());
        final fRate = selectedFreightCurrency == 'EGP'
            ? 1.0
            : (customRate ?? (selectedFreightCurrency == selectedCurrency ? rate : null));
        if (fRate != null && fAmt > 0) {
          final calcFrtEgp = fAmt * fRate;
          multiFreightCtrl.text = calcFrtEgp.toStringAsFixed(3);
        } else {
          multiFreightCtrl.text = '';
        }
      }

      final actualIns = double.tryParse(insuranceCtrl.text.trim()) ?? 0;
      final deemedIns = double.tryParse(deemedInsuranceCtrl.text.trim()) ?? 0;
      final effectiveIns = insuranceType == 'deemed' ? deemedIns : actualIns;

      final actualFrt = double.tryParse(multiFreightCtrl.text.trim()) ?? 0;
      final deemedFrt = double.tryParse(deemedFreightCtrl.text.trim()) ?? 0;
      final effectiveFrt = freightType == 'deemed' ? deemedFrt : actualFrt;

      final calculatedCifEgp = fobEgp + effectiveIns + effectiveFrt;

      setState(() {
        totalInvoiceFcCtrl.text = totalFc > 0 ? totalFc.toStringAsFixed(2) : '';
        declaredCifCtrl.text = calculatedCifEgp > 0 ? calculatedCifEgp.toStringAsFixed(2) : '';
      });
    }

    // Lines extracted from an uploaded invoice (smart upload / PO form) prefill the calculator; values the
    // document did not give stay empty.
    List<Map<String, dynamic>> multiLines = (initialExtractedLines != null && initialExtractedLines.isNotEmpty)
        ? initialExtractedLines.map((line) {
            final hs = line['hs_code']?.toString() ?? line['hs']?.toString() ?? '';
            final val = line['total_price']?.toString() ??
                line['amount']?.toString() ??
                line['value']?.toString() ??
                line['total_amount']?.toString() ??
                '';
            final origin = line['country_of_origin']?.toString() ??
                line['origin_country']?.toString() ??
                line['origin']?.toString();
            return <String, dynamic>{
              'hs': TextEditingController(text: hs),
              'value': TextEditingController(text: val),
              'inspection': TextEditingController(),
              'origin': origin,
              'exemption': null,
              'is_exemption_conditions_met': false,
            };
          }).toList()
        : [
            {
              'hs': TextEditingController(text: initialHsCode ?? ''),
              'value': TextEditingController(),
              'inspection': TextEditingController(),
              'origin': 'CN',
              'exemption': null,
              'is_exemption_conditions_met': false,
            },
          ];

    if (initialExtractedLines != null && initialExtractedLines.isNotEmpty) {
      double sumVal = 0.0;
      for (final l in multiLines) {
        sumVal += double.tryParse((l['value'] as TextEditingController).text) ?? 0.0;
      }
      if (sumVal > 0) totalInvoiceFcCtrl.text = sumVal.toStringAsFixed(2);
      if (initialFreightAmount != null && initialFreightAmount > 0) {
        freightForeignCtrl.text = initialFreightAmount.toStringAsFixed(2);
      }
      if (initialInsuranceAmount != null && initialInsuranceAmount > 0) {
        insuranceCtrl.text = initialInsuranceAmount.toStringAsFixed(2);
      }
    }

    Map<String, dynamic>? multiResult;
    String? multiError;
    bool isMultiCalculating = false;
    bool didAutoSimulate = false;
    bool didInitialRateLoad = false;

    Future<void> runImportFileSimulation(
        int fileId, StateSetter setState) async {
      setState(() {
        isMultiCalculating = true;
        multiError = null;
      });
      try {
        final res = await ref
            .read(customsTariffProvider.notifier)
            .simulateImportFileDuties(fileId);
        if (res != null) {
          setState(() {
            multiResult = res;
            if (res['currency_code'] != null) {
              selectedCurrency = res['currency_code'].toString();
            }
            if (res['exchange_rate'] != null) {
              exchangeRateCtrl.text =
                  _numToDouble(res['exchange_rate']).toStringAsFixed(4);
            }
            if (res['insurance_egp'] != null) {
              insuranceCtrl.text =
                  _numToDouble(res['insurance_egp']).toStringAsFixed(2);
            }
            if (res['insurance_source'] == 'deemed_2.5_percent') {
              insuranceType = 'deemed';
              deemedInsuranceCtrl.text = insuranceCtrl.text;
              insuranceCtrl.text = '0.00';
            } else {
              insuranceType = 'actual';
            }
            if (res['freight_egp'] != null) {
              multiFreightCtrl.text =
                  _numToDouble(res['freight_egp']).toStringAsFixed(2);
            }
            if (res['freight_source'] == 'deemed_2.0_percent') {
              freightType = 'deemed';
              deemedFreightCtrl.text = multiFreightCtrl.text;
              multiFreightCtrl.text = '0.00';
            } else {
              freightType = 'actual';
            }
            if (res['cif_base_egp'] != null) {
              declaredCifCtrl.text =
                  _numToDouble(res['cif_base_egp']).toStringAsFixed(2);
            }
            if (res['total_other_fees_egp'] != null) {
              additionalFeesCtrl.text =
                  _numToDouble(res['total_other_fees_egp']).toStringAsFixed(2);
            }

            final resLines = (res['lines'] as List<dynamic>?) ?? [];
            if (resLines.isNotEmpty) {
              multiLines = resLines.map((l) {
                final lineMap = l as Map<String, dynamic>;
                return {
                  'hs': TextEditingController(
                      text: lineMap['hs_code']?.toString() ?? ''),
                  'value': TextEditingController(
                      text: _numToDouble(lineMap['item_total_fob_foreign'])
                          .toStringAsFixed(2)),
                  'inspection': TextEditingController(
                      text: lineMap['inspection_fee_egp'] != null &&
                              _numToDouble(lineMap['inspection_fee_egp']) > 0
                          ? _numToDouble(lineMap['inspection_fee_egp'])
                              .toStringAsFixed(2)
                          : ''),
                  'origin': lineMap['origin_country']?.toString() ?? 'CN',
                  'exemption':
                      lineMap['preferential_agreement_applied']?.toString(),
                  'is_exemption_conditions_met': lineMap['is_exemption_applied'] == true ||
                      (lineMap['preferential_agreement_applied'] != null &&
                          lineMap['preferential_agreement_applied'].toString().isNotEmpty),
                };
              }).toList();
            }
            syncCalculatedFields(setState, multiLines);
            isMultiCalculating = false;
          });
        }
      } catch (e) {
        setState(() {
          multiError = e.toString().replaceAll('Exception: ', '');
          isMultiCalculating = false;
          multiResult = null;
        });
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setCalcState) {
          final isArabic = Localizations.localeOf(ctx).languageCode == 'ar';
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          if (initialImportFileId != null && !didAutoSimulate) {
            didAutoSimulate = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              runImportFileSimulation(initialImportFileId, setCalcState);
            });
          } else if (initialImportFileId == null && !didInitialRateLoad) {
            didInitialRateLoad = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (exchangeRateCtrl.text.isEmpty) {
                final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
                final currModel = currencies.cast<CurrencyModel?>().firstWhere(
                  (c) => c != null && c.currencyCode.toUpperCase() == selectedCurrency.toUpperCase(),
                  orElse: () => null,
                );
                if (currModel != null &&
                    currModel.latestCustomsRate != null &&
                    currModel.latestCustomsRate! > 0) {
                  setCalcState(() {
                    exchangeRateCtrl.text = currModel.latestCustomsRate!.toStringAsFixed(4);
                    syncCalculatedFields(setCalcState, multiLines);
                  });
                }
              }
            });
          }

          return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.calculate, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic
                      ? 'حاسبة الجمارك المصرية — منصة نافذة'
                      : 'Egyptian Customs Duty Calculator — Nafeza Platform',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 860,
            height: 620,
            child: SelectionArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          isArabic
                              ? 'حساب الجمارك لشحنة متعددة الأصناف وفق نموذج منصة نافذة'
                              : 'Multi-item customs calculation according to Nafeza statement model',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        if (initialImportFileId != null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emerald,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                            ),
                            icon: const Icon(Icons.sync_alt, size: 14),
                            label: Text(
                                isArabic
                                    ? 'محاكاة ملف الاستيراد (#$initialImportFileId)'
                                    : 'Simulate File (#$initialImportFileId)',
                                style: const TextStyle(fontSize: 11)),
                            onPressed: isMultiCalculating
                                ? null
                                : () => runImportFileSimulation(
                                    initialImportFileId, setCalcState),
                          ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.orange,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              icon: const Icon(Icons.downloading, size: 14),
                              label: Text(
                                  isArabic
                                      ? 'تحميل مثال نافذة الفعلي (2026-612-1-94731)'
                                      : 'Load Actual Nafeza Sample (2026-612-1-94731)',
                                  style: const TextStyle(fontSize: 11)),
                              onPressed: () {
                                final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
                                final usdCurr = currencies.cast<CurrencyModel?>().firstWhere(
                                  (c) => c != null && c.currencyCode.toUpperCase() == 'USD',
                                  orElse: () => null,
                                );
                                final dynamicRate = (usdCurr != null &&
                                        usdCurr.latestCustomsRate != null &&
                                        usdCurr.latestCustomsRate! > 0)
                                    ? usdCurr.latestCustomsRate!.toStringAsFixed(4)
                                    : '';
                                setCalcState(() {
                                  selectedCurrency = 'USD';
                                  selectedFreightCurrency = 'USD';
                                  exchangeRateCtrl.text = dynamicRate;
                                  insuranceCtrl.text = '14902.793';
                                  deemedInsuranceCtrl.text = '0.00';
                                  insuranceType = 'actual';
                                  freightForeignCtrl.text = '234.72';
                                  multiFreightCtrl.text = '11922.234';
                                  deemedFreightCtrl.text = '0.00';
                                  freightType = 'actual';
                                  additionalFeesCtrl.text = '1329.50';
                                  multiLines = [
                                    {
                                      'hs': TextEditingController(text: '8536.41.00'),
                                      'value': TextEditingController(text: '607.6'),
                                      'inspection':
                                          TextEditingController(text: '0.00'),
                                      'origin': 'CN',
                                      'exemption': null,
                                    },
                                    {
                                      'hs': TextEditingController(text: '8537.10.90'),
                                      'value': TextEditingController(text: '4371.2'),
                                      'inspection':
                                          TextEditingController(text: '8514.81'),
                                      'origin': 'TR',
                                      'exemption': null,
                                    },
                                    {
                                      'hs': TextEditingController(text: '8537.10.90'),
                                      'value': TextEditingController(text: '6757.6'),
                                      'inspection':
                                          TextEditingController(text: '69772.09'),
                                      'origin': 'DE',
                                      'exemption': null,
                                    },
                                  ];
                                  syncCalculatedFields(setCalcState, multiLines);
                                });
                              },
                            ),
                          ],
                        ),
                  const SizedBox(height: 12),

                  // Header Inputs Grid - Row 1: Invoice Currency + Exchange Rate + Total FC Auto-Calc
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: SearchableDropdownField<String>(
                          value: selectedCurrency,
                          labelText: isArabic ? 'عملة الفاتورة *' : 'Invoice Currency *',
                          searchHintText: isArabic ? 'ابحث عن عملة الفاتورة...' : 'Search currency...',
                          items: [
                            SearchableDropdownItem(
                                value: 'USD', label: isArabic ? 'USD - دولار (\$)' : 'USD - US Dollar (\$)'),
                            SearchableDropdownItem(
                                value: 'EUR', label: isArabic ? 'EUR - يورو (€)' : 'EUR - Euro (€)'),
                            SearchableDropdownItem(
                                value: 'GBP', label: isArabic ? 'GBP - إسترليني (£)' : 'GBP - Sterling (£)'),
                            SearchableDropdownItem(
                                value: 'CNY', label: isArabic ? 'CNY - يوان (¥)' : 'CNY - Yuan (¥)'),
                            SearchableDropdownItem(
                                value: 'SAR', label: isArabic ? 'SAR - ريال (ر.س)' : 'SAR - Riyal (SAR)'),
                            SearchableDropdownItem(
                                value: 'AED', label: isArabic ? 'AED - درهم (د.إ)' : 'AED - Dirham (AED)'),
                            SearchableDropdownItem(
                                value: 'EGP', label: isArabic ? 'EGP - جنيه (ج.م)' : 'EGP - Pound (EGP)'),
                          ],
                          onChanged: (val) {
                            if (val == null) return;
                            setCalcState(() {
                              selectedCurrency = val;
                              if (freightType == 'actual' &&
                                  selectedFreightCurrency == 'USD') {
                                selectedFreightCurrency = val;
                              }
                              final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
                              final currModel = currencies.cast<CurrencyModel?>().firstWhere(
                                (c) => c != null && c.currencyCode.toUpperCase() == val.toUpperCase(),
                                orElse: () => null,
                              );
                              if (currModel != null &&
                                  currModel.latestCustomsRate != null &&
                                  currModel.latestCustomsRate! > 0) {
                                exchangeRateCtrl.text =
                                    currModel.latestCustomsRate!.toStringAsFixed(4);
                              } else if (val == 'EGP') {
                                exchangeRateCtrl.text = '1.0000';
                              } else {
                                exchangeRateCtrl.text = '';
                              }
                              syncCalculatedFields(setCalcState, multiLines);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: exchangeRateCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) =>
                              syncCalculatedFields(setCalcState, multiLines),
                          decoration: InputDecoration(
                            labelText: isArabic
                                ? 'سعر التحويل (EGP/$selectedCurrency) *'
                                : 'Exchange Rate (EGP/$selectedCurrency) *',
                            hintText: isArabic ? 'سعر الصرف الجمركي' : 'Customs Rate',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: totalInvoiceFcCtrl,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: isArabic
                                ? 'إجمالي قيمة الفاتورة المقر عنها ($selectedCurrency)'
                                : 'Total Declared Invoice Value ($selectedCurrency)',
                            helperText: isArabic
                                ? 'حاصل جمع قيم جميع السطور بالعملة'
                                : 'Sum of all invoice lines in currency',
                            helperStyle: const TextStyle(fontSize: 9),
                            isDense: true,
                            filled: true,
                            fillColor: AppTheme.cobalt.withOpacity(0.08),
                            suffixIcon: const Icon(Icons.calculate_outlined,
                                size: 16, color: AppTheme.cobalt),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Header Inputs Grid - Row 2: Declared CIF EGP + Additional Fees EGP
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: declaredCifCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isArabic
                                ? 'إجمالي القيمة المقرة CIF (EGP)'
                                : 'Declared CIF Value (EGP)',
                            helperText: isArabic
                                ? 'محسوبة تلقائياً: (FOB + تأمين + نولون)'
                                : 'Calculated: (FOB + Insurance + Freight)',
                            helperStyle: const TextStyle(fontSize: 9),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: additionalFeesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isArabic
                                ? 'رسوم أساسية/إضافية (EGP)'
                                : 'Basic / Additional Fees (EGP)',
                            hintText: '0.00',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Insurance Interactive Row ──
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: (insuranceType == 'deemed'
                              ? AppTheme.orange
                              : AppTheme.cobalt)
                          .withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (insuranceType == 'deemed'
                                ? AppTheme.orange
                                : AppTheme.cobalt)
                            .withOpacity(0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              insuranceType == 'actual'
                                  ? Icons.verified_outlined
                                  : Icons.auto_fix_high,
                              size: 14,
                              color: insuranceType == 'actual'
                                  ? AppTheme.cobalt
                                  : AppTheme.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(isArabic ? 'التأمين:' : 'Insurance:',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.charcoal)),
                            const SizedBox(width: 12),
                            ChoiceChip(
                              label: Text(isArabic ? 'فعلي ✔' : 'Actual ✔',
                                  style: const TextStyle(fontSize: 11)),
                              selected: insuranceType == 'actual',
                              selectedColor: AppTheme.cobalt.withOpacity(0.2),
                              onSelected: (_) {
                                setCalcState(() {
                                  insuranceType = 'actual';
                                  deemedInsuranceCtrl.text = '';
                                  syncCalculatedFields(
                                      setCalcState, multiLines);
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: Text(isArabic ? 'حكمي 2.5% ⚡' : 'Deemed 2.5% ⚡',
                                  style: const TextStyle(fontSize: 11)),
                              selected: insuranceType == 'deemed',
                              selectedColor: AppTheme.orange.withOpacity(0.2),
                              onSelected: (_) {
                                setCalcState(() {
                                  insuranceType = 'deemed';
                                  insuranceCtrl.text = '';
                                  recalcDeemedInsurance(
                                      setCalcState, multiLines);
                                  syncCalculatedFields(
                                      setCalcState, multiLines);
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (insuranceType == 'actual') ...[
                              Expanded(
                                child: TextField(
                                  controller: insuranceCtrl,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => syncCalculatedFields(
                                      setCalcState, multiLines),
                                  decoration: InputDecoration(
                                    labelText: isArabic
                                        ? 'مبلغ التأمين الفعلي (EGP)'
                                        : 'Actual Insurance Amount (EGP)',
                                    hintText: '0.00',
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: TextField(
                                  controller: deemedInsuranceCtrl,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: isArabic
                                        ? 'التأمين الحكمي المحتسب (EGP) — 2.5% من إجمالي FOB'
                                        : 'Deemed Insurance (EGP) — 2.5% of FOB',
                                    isDense: true,
                                    filled: true,
                                    fillColor:
                                        AppTheme.orange.withOpacity(0.08),
                                    suffixIcon: const Icon(
                                        Icons.calculate_outlined,
                                        size: 16,
                                        color: AppTheme.orange),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: insuranceCtrl,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: isArabic
                                        ? 'التأمين الفعلي (EGP) — يُضبط صفراً'
                                        : 'Actual Insurance (EGP) — set to 0',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.grey.withOpacity(0.08),
                                    helperText: isArabic
                                        ? 'صفر لتجنب الاحتساب المزدوج'
                                        : 'Zero to prevent double counting',
                                    helperStyle: const TextStyle(
                                        fontSize: 9, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Freight Interactive Row (Foreign Currency & Amount) ──
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: (freightType == 'deemed'
                              ? AppTheme.orange
                              : AppTheme.cobalt)
                          .withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (freightType == 'deemed'
                                ? AppTheme.orange
                                : AppTheme.cobalt)
                            .withOpacity(0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              freightType == 'actual'
                                  ? Icons.local_shipping_outlined
                                  : Icons.auto_fix_high,
                              size: 14,
                              color: freightType == 'actual'
                                  ? AppTheme.cobalt
                                  : AppTheme.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(isArabic ? 'النولون:' : 'Freight:',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.charcoal)),
                            const SizedBox(width: 12),
                            ChoiceChip(
                              label: Text(isArabic ? 'فعلي ✔' : 'Actual ✔',
                                  style: const TextStyle(fontSize: 11)),
                              selected: freightType == 'actual',
                              selectedColor: AppTheme.cobalt.withOpacity(0.2),
                              onSelected: (_) {
                                setCalcState(() {
                                  freightType = 'actual';
                                  deemedFreightCtrl.text = '';
                                  syncCalculatedFields(
                                      setCalcState, multiLines);
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: Text(isArabic ? 'حكمي 2.0% ⚡' : 'Deemed 2.0% ⚡',
                                  style: const TextStyle(fontSize: 11)),
                              selected: freightType == 'deemed',
                              selectedColor: AppTheme.orange.withOpacity(0.2),
                              onSelected: (_) {
                                setCalcState(() {
                                  freightType = 'deemed';
                                  multiFreightCtrl.text = '';
                                  recalcDeemedFreight(setCalcState, multiLines);
                                  syncCalculatedFields(
                                      setCalcState, multiLines);
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (freightType == 'actual') ...[
                              Expanded(
                                flex: 2,
                                child: SearchableDropdownField<String>(
                                  value: selectedFreightCurrency,
                                  labelText: isArabic
                                      ? 'عملة النولون الفعلي *'
                                      : 'Actual Freight Currency *',
                                  searchHintText: isArabic
                                      ? 'ابحث عن عملة النولون...'
                                      : 'Search freight currency...',
                                  items: [
                                    SearchableDropdownItem(
                                        value: 'USD',
                                        label: isArabic ? 'USD - دولار (\$)' : 'USD - Dollar (\$)'),
                                    SearchableDropdownItem(
                                        value: 'EUR', label: isArabic ? 'EUR - يورو (€)' : 'EUR - Euro (€)'),
                                    SearchableDropdownItem(
                                        value: 'GBP',
                                        label: isArabic ? 'GBP - إسترليني (£)' : 'GBP - Sterling (£)'),
                                    SearchableDropdownItem(
                                        value: 'CNY', label: isArabic ? 'CNY - يوان (¥)' : 'CNY - Yuan (¥)'),
                                    SearchableDropdownItem(
                                        value: 'SAR',
                                        label: isArabic ? 'SAR - ريال (ر.س)' : 'SAR - Riyal (SAR)'),
                                    SearchableDropdownItem(
                                        value: 'AED',
                                        label: isArabic ? 'AED - درهم (د.إ)' : 'AED - Dirham (AED)'),
                                    SearchableDropdownItem(
                                        value: 'EGP',
                                        label: isArabic ? 'EGP - جنيه (ج.م)' : 'EGP - Pound (EGP)'),
                                  ],
                                  onChanged: (val) {
                                    if (val == null) return;
                                    setCalcState(() {
                                      selectedFreightCurrency = val;
                                      freightExchangeRateCtrl.text = '';
                                      syncCalculatedFields(
                                          setCalcState, multiLines);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: freightForeignCtrl,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => syncCalculatedFields(
                                      setCalcState, multiLines),
                                  decoration: InputDecoration(
                                    labelText: isArabic
                                        ? 'مبلغ النولون ($selectedFreightCurrency) *'
                                        : 'Freight Amount ($selectedFreightCurrency) *',
                                    hintText: '0.00',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (selectedFreightCurrency != 'EGP') ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: freightExchangeRateCtrl,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => syncCalculatedFields(
                                        setCalcState, multiLines),
                                    decoration: InputDecoration(
                                      labelText: isArabic
                                          ? 'معامل تحويل عملة النولون (اختياري)'
                                          : 'Freight FX Override (Optional)',
                                      hintText: isArabic
                                          ? 'اتركه فارغاً لاستخدام سعر الجمارك'
                                          : 'Leave blank for customs rate',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: multiFreightCtrl,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: isArabic
                                        ? 'إجمالي النولون الفعلي (EGP)'
                                        : 'Total Actual Freight (EGP)',
                                    helperText: selectedFreightCurrency == 'EGP'
                                        ? (isArabic ? 'نولون بالجنيه' : 'Freight in EGP')
                                        : (isArabic
                                            ? '= النولون ($selectedFreightCurrency) × معامل التحويل'
                                            : '= Freight ($selectedFreightCurrency) × FX Rate'),
                                    helperStyle: const TextStyle(fontSize: 9),
                                    isDense: true,
                                    filled: true,
                                    fillColor:
                                        AppTheme.cobalt.withOpacity(0.08),
                                    suffixIcon: const Icon(
                                        Icons.calculate_outlined,
                                        size: 16,
                                        color: AppTheme.cobalt),
                                  ),
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: TextField(
                                  controller: deemedFreightCtrl,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: isArabic
                                        ? 'النولون الحكمي المحتسب (EGP) — 2.0% من إجمالي FOB'
                                        : 'Deemed Freight (EGP) — 2.0% of FOB',
                                    isDense: true,
                                    filled: true,
                                    fillColor:
                                        AppTheme.orange.withOpacity(0.08),
                                    suffixIcon: const Icon(
                                        Icons.calculate_outlined,
                                        size: 16,
                                        color: AppTheme.orange),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: multiFreightCtrl,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: isArabic
                                        ? 'النولون الفعلي (EGP) — يُضبط صفراً'
                                        : 'Actual Freight (EGP) — set to 0',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.grey.withOpacity(0.08),
                                    helperText: isArabic
                                        ? 'صفر لتجنب الاحتساب المزدوج'
                                        : 'Zero to prevent double counting',
                                    helperStyle: const TextStyle(
                                        fontSize: 9, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lines Table Title & Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic
                            ? 'سطور الفاتورة (Invoice Line Items):'
                            : 'Invoice Line Items:',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.charcoal,
                            fontSize: 13),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                            isArabic ? 'إضافة صنف +' : 'Add Item +',
                            style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          setCalcState(() {
                            multiLines.add({
                              'hs': TextEditingController(),
                              'value': TextEditingController(),
                              'inspection': TextEditingController(),
                              'origin': 'CN',
                              'exemption': null,
                              'is_exemption_conditions_met': false,
                            });
                            syncCalculatedFields(setCalcState, multiLines);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Multi-Lines Input List
                  ...multiLines.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final m = entry.value;
                    final registeredTariffs =
                        ref.watch(customsTariffProvider).valueOrNull ?? [];
                    final hsDropdownItems = registeredTariffs
                        .map((t) => SearchableDropdownItem<String>(
                              value: t.hsCode,
                              label: '[${t.hsCode}] ${t.hsDescription}',
                              subtitle: isArabic
                                  ? 'الوارد: ${t.customsDutyRate}% | ض.م: ${t.vatRate}%'
                                  : 'Duty: ${t.customsDutyRate}% | VAT: ${t.vatRate}%',
                            ))
                        .toList();

                    final currentHs =
                        (m['hs'] as TextEditingController).text.trim();
                    final matchedTariff = registeredTariffs
                        .cast<CustomsTariffModel?>()
                        .firstWhere(
                          (t) =>
                              t != null &&
                              (t.hsCode == currentHs ||
                                  t.hsCode.replaceAll('.', '') ==
                                      currentHs.replaceAll('.', '')),
                          orElse: () => null,
                        );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: AppTheme.cobalt,
                                child: Text('${idx + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: SearchableDropdownField<String>(
                                  value: currentHs.isEmpty ? null : currentHs,
                                  labelText: isArabic
                                      ? 'HS Code (بند التعريفة الجمركية) *'
                                      : 'HS Code (Customs Tariff) *',
                                  searchHintText: isArabic
                                      ? 'ابحث برقم البند أو الوصف الجمركي...'
                                      : 'Search HS code or description...',
                                  items: [
                                    if (currentHs.isNotEmpty &&
                                        !registeredTariffs
                                            .any((t) => t.hsCode == currentHs))
                                      SearchableDropdownItem<String>(
                                        value: currentHs,
                                        label: currentHs,
                                        subtitle: isArabic ? 'بند غير مسجل / حرة' : 'Unregistered / Free',
                                      ),
                                    ...hsDropdownItems,
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setCalcState(() {
                                        (m['hs'] as TextEditingController)
                                            .text = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller:
                                      m['value'] as TextEditingController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => syncCalculatedFields(
                                      setCalcState, multiLines),
                                  decoration: InputDecoration(
                                    labelText: isArabic ? 'القيمة ($selectedCurrency)' : 'Value ($selectedCurrency)',
                                    hintText: '0.00',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: SearchableDropdownField<String>(
                                  value: m['origin'] as String?,
                                  labelText: isArabic ? 'المنشأ' : 'Origin',
                                  searchHintText: isArabic ? 'ابحث عن بلد المنشأ...' : 'Search origin...',
                                  items: [
                                    SearchableDropdownItem(
                                        value: 'CN', label: isArabic ? 'الصين - CN' : 'China - CN'),
                                    SearchableDropdownItem(
                                        value: 'TR',
                                        label: isArabic ? 'تركيا (اتفاقية) - TR' : 'Turkey (Agreement) - TR'),
                                    SearchableDropdownItem(
                                        value: 'DE',
                                        label: isArabic ? 'ألمانيا (شراكة) - DE' : 'Germany (Partnership) - DE'),
                                    SearchableDropdownItem(
                                        value: 'IT',
                                        label: isArabic ? 'إيطاليا (شراكة) - IT' : 'Italy (Partnership) - IT'),
                                    SearchableDropdownItem(
                                        value: 'EG', label: isArabic ? 'مصر - EG' : 'Egypt - EG'),
                                    SearchableDropdownItem(
                                        value: 'GB',
                                        label: isArabic ? 'المملكة المتحدة - GB' : 'United Kingdom - GB'),
                                    SearchableDropdownItem(
                                        value: 'US', label: isArabic ? 'أمريكا - US' : 'United States - US'),
                                    SearchableDropdownItem(
                                        value: 'IN', label: isArabic ? 'الهند - IN' : 'India - IN'),
                                    SearchableDropdownItem(
                                        value: 'BR',
                                        label: isArabic ? 'البرازيل (ميركوسور) - BR' : 'Brazil (Mercosur) - BR'),
                                    SearchableDropdownItem(
                                        value: 'RS',
                                        label: isArabic ? 'صربيا (اتفاقية) - RS' : 'Serbia (Agreement) - RS'),
                                    SearchableDropdownItem(
                                        value: 'CH',
                                        label: isArabic ? 'سويسرا (إفتا) - CH' : 'Switzerland (EFTA) - CH'),
                                  ],
                                  onChanged: (val) {
                                    setCalcState(() {
                                      m['origin'] = val;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: SearchableDropdownField<String?>(
                                  value: m['exemption'] as String?,
                                  labelText: isArabic ? 'الإعفاء' : 'Exemption',
                                  searchHintText: isArabic ? 'ابحث عن كود الإعفاء...' : 'Search exemption...',
                                  items: [
                                    SearchableDropdownItem(
                                        value: null, label: isArabic ? 'لا يوجد إعفاء' : 'No Exemption'),
                                    SearchableDropdownItem(
                                        value: 'INV-LAW-EXEMPT-01',
                                        label: isArabic ? 'قانون الاستثمار (100%)' : 'Investment Law (100%)'),
                                    SearchableDropdownItem(
                                        value: 'FREEZONE-EXEMPT-02',
                                        label: isArabic ? 'منطقة حرة (100%)' : 'Free Zone (100%)'),
                                    SearchableDropdownItem(
                                        value: 'DIPLO-EXEMPT-03',
                                        label: isArabic ? 'إعفاء دبلوماسي (100%)' : 'Diplomatic Exemption (100%)'),
                                    SearchableDropdownItem(
                                        value: 'PARTIAL-50-EXEMPT',
                                        label: isArabic ? 'إعفاء جزئي (50%)' : 'Partial Exemption (50%)'),
                                  ],
                                  onChanged: (val) {
                                    setCalcState(() {
                                      m['exemption'] = val;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller:
                                      m['inspection'] as TextEditingController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: isArabic ? 'خدمات جمركية (EGP)' : 'Customs Services (EGP)',
                                    hintText: '0.00',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (multiLines.length > 1) ...[
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 18),
                                  onPressed: () {
                                    setCalcState(() {
                                      multiLines.removeAt(idx);
                                      syncCalculatedFields(
                                          setCalcState, multiLines);
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                          if (matchedTariff != null &&
                              (matchedTariff.priorApprovalNote ?? '')
                                  .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: Colors.amber.shade700),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          color: Colors.amber.shade900,
                                          size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        isArabic
                                            ? '⚠️ تنبيه إعفاء وشروط مستندية مطلوبة للمورد الخارجي (HS Code: ${matchedTariff.hsCode}):'
                                            : '⚠️ Exemption & Documentary Requirements for Foreign Supplier (HS Code: ${matchedTariff.hsCode}):',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isArabic
                                        ? '• توجد اتفاقيات وشروط مستندية يجب طلب استيفائها من المورد الخارجي (مثل شهادة EUR.1 الأصلي أو منشأ الميركسور) قبل تطبيق الإعفاء الجمركي:'
                                        : '• Documentary requirements must be requested from foreign supplier (e.g. Original EUR.1 or Mercosur origin) prior to tariff exemption:',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.amber.shade900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    matchedTariff.priorApprovalNote!,
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.charcoal,
                                        height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Interactive Exemption Checklist Checkbox (Requirements 3 & 4)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (m['is_exemption_conditions_met'] == true)
                                  ? AppTheme.emerald.withOpacity(isDark ? 0.2 : 0.08)
                                  : (isDark ? AppTheme.darkSurface : Colors.grey.withOpacity(0.04)),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (m['is_exemption_conditions_met'] == true)
                                    ? AppTheme.emerald
                                    : (isDark ? AppTheme.darkBorder : Colors.grey.withOpacity(0.25)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: m['is_exemption_conditions_met'] == true,
                                  activeColor: AppTheme.emerald,
                                  onChanged: (bool? val) async {
                                    final isChecked = val ?? false;
                                    setCalcState(() {
                                      m['is_exemption_conditions_met'] = isChecked;
                                    });

                                    // Task Automation (Requirement 4):
                                    if (isChecked && initialImportFileId != null) {
                                      final hsCodeStr = (m['hs'] as TextEditingController).text.trim();
                                      try {
                                        await ref.read(smartTasksProvider.notifier).createTask({
                                          'title': 'Mandatory task: meet the exemption conditions for HS [$hsCodeStr] (matching certificate of origin / agreement requirements / required documents) to avoid the import duty.',
                                          'description': 'The customs exemption conditions option was enabled in the customs calculator for HS $hsCodeStr. Meet the agreement conditions and provide the matching certificate of origin and all required documents to avoid the import duty.',
                                          'task_type': 'System Generated',
                                          'priority': 'Critical',
                                          'reminder_type': 'Document',
                                          'status': 'Pending',
                                          'import_file_id': initialImportFileId,
                                        });
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: AppTheme.emerald,
                                              content: Text(
                                                isArabic
                                                    ? '✅ مهمة إلزامية: تم تسجيل مهمة في قائمة مهام الشحنة لاستيفاء شروط ومستندات إعفاء البند [$hsCodeStr]'
                                                    : '✅ Mandatory task created in shipment checklist for HS [$hsCodeStr] exemption conditions',
                                              ),
                                              duration: const Duration(seconds: 4),
                                            ),
                                          );
                                        }
                                      } catch (_) {}
                                    }
                                  },
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    isArabic
                                        ? 'هل سيتم استيفاء وتطبيق شروط الإعفاء الجمركي لهذا البند؟ (اتفاقية شراكة / تصنيع / شهادة منشأ مستوفاة)'
                                        : 'Will customs exemption conditions be fulfilled for this item? (Partnership / Manufacturing / COO fulfilled)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: (m['is_exemption_conditions_met'] == true)
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: (m['is_exemption_conditions_met'] == true)
                                          ? (isDark ? Colors.green.shade300 : AppTheme.emerald)
                                          : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    ),
                                  ),
                                ),
                                if (m['is_exemption_conditions_met'] == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emerald.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.emerald.withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      isArabic ? 'معفى (0% جمرك)' : 'Exempt (0% Duty)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.green.shade300 : AppTheme.emerald,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // Submit Calculation Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: isMultiCalculating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.bolt, size: 20),
                      label: Text(
                        isArabic
                            ? 'حساب إجمالي الجمارك والإقرار الرسمي (Calculate Nafeza Duties)'
                            : 'Calculate Nafeza Duties & Official Statement',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      onPressed: isMultiCalculating
                          ? null
                          : () async {
                              final rate = double.tryParse(
                                      exchangeRateCtrl.text.trim()) ??
                                  0.0;
                              if (rate <= 0) {
                                setCalcState(() {
                                  multiError = isArabic
                                      ? 'يرجى إدخال أو اختيار سعر تحويل صحيح للعملة أولاً'
                                      : 'Please enter or select a valid exchange rate first';
                                });
                                return;
                              }

                              final bool isDeemedInsurance =
                                  insuranceType == 'deemed';
                              final double actualIns = isDeemedInsurance
                                  ? 0.0
                                  : (double.tryParse(
                                          insuranceCtrl.text.trim()) ??
                                      0);

                              final bool isDeemedFreight =
                                  freightType == 'deemed';
                              final double actualFrt = isDeemedFreight
                                  ? 0.0
                                  : (double.tryParse(
                                          multiFreightCtrl.text.trim()) ??
                                      0);

                              final add = double.tryParse(
                                      additionalFeesCtrl.text.trim()) ??
                                  0;
                              final decCif =
                                  double.tryParse(declaredCifCtrl.text.trim());

                              final linesData = <Map<String, dynamic>>[];
                              for (int i = 0; i < multiLines.length; i++) {
                                final m = multiLines[i];
                                linesData.add({
                                  'line_no': i + 1,
                                  'hs_code': (m['hs'] as TextEditingController)
                                      .text
                                      .trim(),
                                  'value_fc': double.tryParse(
                                          (m['value'] as TextEditingController)
                                              .text
                                              .trim()) ??
                                      0,
                                  'inspection_fee_egp': double.tryParse(
                                          (m['inspection']
                                                  as TextEditingController)
                                              .text
                                              .trim()) ??
                                      0,
                                  'origin_country': m['origin'],
                                  'exemption_code': m['exemption'],
                                  'is_exemption_conditions_met': m['is_exemption_conditions_met'] == true,
                                });
                              }

                              if (linesData.isEmpty || linesData.any((l) => (l['hs_code'] as String).isEmpty || (l['value_fc'] as double) <= 0)) {
                                setCalcState(() {
                                  multiError = isArabic
                                      ? 'يرجى إدخال بند جمركي وقيمة صالحة أكبر من صفر لكل صنف'
                                      : 'Please enter a valid HS code and value greater than 0 for all items';
                                });
                                return;
                              }

                              setCalcState(() {
                                isMultiCalculating = true;
                                multiError = null;
                              });

                              try {
                                final payload = {
                                  'currency': selectedCurrency,
                                  'exchange_rate': rate,
                                  'insurance_egp': actualIns,
                                  'freight_egp': actualFrt,
                                  'freight_currency': selectedFreightCurrency,
                                  'freight_foreign_amount': double.tryParse(
                                          freightForeignCtrl.text.trim()) ??
                                      0,
                                  if (double.tryParse(freightExchangeRateCtrl.text.trim()) != null &&
                                      double.parse(freightExchangeRateCtrl.text.trim()) > 0)
                                    'freight_exchange_rate': double.parse(freightExchangeRateCtrl.text.trim()),
                                  'has_insurance_document': !isDeemedInsurance,
                                  'has_freight_document': !isDeemedFreight,
                                  'additional_fees_egp': add,
                                  if (decCif != null && decCif > 0)
                                    'cif_declared_total_egp': decCif,
                                  'lines': linesData,
                                };

                                final res = await ref
                                    .read(customsTariffProvider.notifier)
                                    .estimateMultiItemDuty(payload);

                                setCalcState(() {
                                  multiResult = res;
                                  isMultiCalculating = false;
                                });
                              } catch (e) {
                                setCalcState(() {
                                  multiError = e
                                      .toString()
                                      .replaceAll('Exception: ', '');
                                  isMultiCalculating = false;
                                  multiResult = null;
                                });
                              }
                            },
                    ),
                  ),

                  if (multiError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(multiError!,
                                  style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (multiResult != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    Text(
                        isArabic
                            ? 'نتيجة حساب الشحنة (إقرار نافذة):'
                            : 'Shipment Calculation Result (Nafeza Statement):',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.charcoal,
                            fontSize: 13)),
                    const SizedBox(height: 8),

                    // Multi-Item Line Items Results Table
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 12,
                        headingRowHeight: 32,
                        dataRowMinHeight: 32,
                        dataRowMaxHeight: 32,
                        headingRowColor: WidgetStateProperty.all(
                            AppTheme.charcoal.withOpacity(0.05)),
                        columns: [
                          DataColumn(label: Text(isArabic ? 'سطر' : 'Line')),
                          const DataColumn(label: Text('HS Code')),
                          DataColumn(label: Text(isArabic ? 'المنشأ / الاتفاقية' : 'Origin / Agreement')),
                          const DataColumn(label: Text('CIF (EGP)')),
                          DataColumn(label: Text(isArabic ? 'جمرك' : 'Duty')),
                          DataColumn(label: Text(isArabic ? 'ض.جدول' : 'Schedule Tax')),
                          DataColumn(label: Text(isArabic ? 'أ.ن.ص (1%)' : 'Service Fee (1%)')),
                          const DataColumn(label: Text('VAT (14%)')),
                          DataColumn(
                              label: Text(isArabic ? 'ملاحظات الإعفاء والاتفاقيات' : 'Exemption / Agreement Notes')),
                        ],
                        rows: (multiResult!['lines'] as List).map((l) {
                          return DataRow(cells: [
                            DataCell(Text('#${l['line_no']}')),
                            DataCell(Text(l['hs_code'].toString())),
                            DataCell(Text(
                                l['preferential_agreement_applied'] != null
                                    ? '${l['origin_country']} (${isArabic ? "تفضيل 0%" : "Pref. 0%"})'
                                    : '${l['origin_country'] ?? "-"}')),
                            DataCell(Text('${l['cif_value_egp']} EGP')),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    '${l['duty_egp']} EGP (${l['customs_duty_rate']}%)'),
                                if (_numToDouble(l['customs_duty_rate']) == 0.0 ||
                                    l['is_exemption_applied'] == true) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emerald.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: AppTheme.emerald
                                              .withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      isArabic
                                          ? 'معفى بموجب اتفاقية / استيفاء الشروط'
                                          : 'Exempt per agreement',
                                      style: const TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.emerald,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            )),
                            DataCell(Text('${l['schedule_tax_egp']} EGP')),
                            DataCell(Text(
                                '${l['customs_service_fee_egp']} EGP (1%)')),
                            DataCell(Text('${l['vat_egp']} EGP')),
                            DataCell(Text(
                                l['exemption_applied_details'] ??
                                    l['preferential_agreement_applied'] ??
                                    (isArabic ? 'خاضع بالكامل' : 'Fully Taxable'),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: (l['exemption_applied_details'] !=
                                                null ||
                                            l['preferential_agreement_applied'] !=
                                                null)
                                        ? AppTheme.emerald
                                        : Colors.black87))),
                          ]);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),

                    // ── Nafeza Statement Fee Codes Breakdown Table (Matching Image #3 Layout) ──
                    if (multiResult!['fee_codes_breakdown'] != null) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.cobalt.withOpacity(0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Header Bar
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withOpacity(0.12),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(9)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.receipt_long,
                                          color: AppTheme.cobalt, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        isArabic
                                            ? 'تفاصيل بنود التحصيل والإقرارات الرسمية'
                                            : 'Nafeza Statement Fee Breakdown & Official Declarations',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.cobalt,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    isArabic
                                        ? 'إجمالي البيان: ${_numToDouble(multiResult!['fee_codes_breakdown']['grand_total']).toStringAsFixed(2)} ج.م'
                                        : 'Statement Grand Total: ${_numToDouble(multiResult!['fee_codes_breakdown']['grand_total']).toStringAsFixed(2)} EGP',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.cobalt,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),

                            // Grouped Fee Items (Matching Nafeza Official PDF layout in Image #3)
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                children: [
                                  ...((multiResult!['fee_codes_breakdown']
                                                  ['group_items']
                                              as Map<String, dynamic>? ??
                                          {})
                                      .entries
                                      .map((groupEntry) {
                                    final groupName = groupEntry.key;
                                    final itemsList =
                                        groupEntry.value as List<dynamic>? ??
                                            [];
                                    final groupSum =
                                        (multiResult!['fee_codes_breakdown']
                                                        ['by_group']
                                                    as Map<String, dynamic>? ??
                                                {})[groupName] ??
                                            0.0;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Column(
                                        children: [
                                          // Group Subheader Bar
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            color: Colors.blueGrey.shade100
                                                .withOpacity(0.4),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                    isArabic
                                                        ? 'تحصيل $groupName'
                                                        : 'Collection: $groupName',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                        color:
                                                            AppTheme.charcoal)),
                                                Text(
                                                    '${_numToDouble(groupSum).toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                        color:
                                                            AppTheme.charcoal)),
                                              ],
                                            ),
                                          ),
                                          // Group Items List
                                          ...itemsList.map((item) {
                                            final itemMap =
                                                item as Map<String, dynamic>;
                                            final code =
                                                itemMap['code']?.toString() ??
                                                    '';
                                            final name = itemMap['name_ar']
                                                    ?.toString() ??
                                                '';
                                            final calcType =
                                                itemMap['calculation_type']
                                                        ?.toString() ??
                                                    'flat';
                                            final amt = _numToDouble(
                                                itemMap['calculated_amount']);
                                            final typeLabel = calcType == 'flat'
                                                ? (isArabic ? 'قطعي' : 'Flat')
                                                : (calcType == 'reference'
                                                    ? (isArabic ? 'مرجعي' : 'Ref')
                                                    : (isArabic ? 'مشتق' : 'Derived'));

                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 5),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade200,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Text('[$code]',
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontFamily:
                                                                'monospace')),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(name,
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500)),
                                                  ),
                                                  Text(typeLabel,
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors
                                                              .grey.shade600)),
                                                  const SizedBox(width: 14),
                                                  SizedBox(
                                                    width: 95,
                                                    child: Text(
                                                        '${amt.toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}',
                                                        textAlign:
                                                            TextAlign.end,
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    );
                                  })),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Action Buttons: Print Statement & Download PDF
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.charcoal,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.print, size: 16),
                            label: Text(
                                isArabic ? 'طباعة التقرير 🖨️' : 'Print Statement 🖨️',
                                style: const TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final rate = double.tryParse(
                                      exchangeRateCtrl.text.trim()) ??
                                  _numToDouble(multiResult!['exchange_rate'], 1.0);
                              final totalFc = computeTotalInvoiceFc(multiLines);
                              final fobEgp = totalFc * rate;
                              final insEgp = (insuranceType == 'deemed')
                                  ? (double.tryParse(
                                          deemedInsuranceCtrl.text.trim()) ??
                                      0)
                                  : (double.tryParse(
                                          insuranceCtrl.text.trim()) ??
                                      0);
                              final frtEgp = (freightType == 'deemed')
                                  ? (double.tryParse(
                                          deemedFreightCtrl.text.trim()) ??
                                      0)
                                  : (double.tryParse(
                                          multiFreightCtrl.text.trim()) ??
                                      0);
                              final addEgp = double.tryParse(
                                      additionalFeesCtrl.text.trim()) ??
                                  0;
                              final cifEgp = double.tryParse(
                                      declaredCifCtrl.text.trim()) ??
                                  (fobEgp + insEgp + frtEgp);

                              await CustomsPdfService.printStatement(
                                currency: selectedCurrency,
                                exchangeRate: rate,
                                totalFobFc: totalFc,
                                totalFobEgp: fobEgp,
                                insuranceEgp: insEgp,
                                freightEgp: frtEgp,
                                additionalFeesEgp: addEgp,
                                totalCifEgp: cifEgp,
                                insuranceMode: insuranceType == 'deemed'
                                    ? (isArabic ? 'حكمي 2.5%' : 'Deemed 2.5%')
                                    : (isArabic ? 'فعلي' : 'Actual'),
                                freightMode: freightType == 'deemed'
                                    ? (isArabic ? 'حكمي 2.0%' : 'Deemed 2.0%')
                                    : (isArabic ? 'فعلي' : 'Actual'),
                                result: multiResult!,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cobalt,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.picture_as_pdf, size: 16),
                            label: Text(
                                isArabic ? 'تنزيل PDF 📄' : 'Download PDF 📄',
                                style: const TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final rate = double.tryParse(
                                      exchangeRateCtrl.text.trim()) ??
                                  _numToDouble(multiResult!['exchange_rate'], 1.0);
                              final totalFc = computeTotalInvoiceFc(multiLines);
                              final fobEgp = totalFc * rate;
                              final insEgp = (insuranceType == 'deemed')
                                  ? (double.tryParse(
                                          deemedInsuranceCtrl.text.trim()) ??
                                      0)
                                  : (double.tryParse(
                                          insuranceCtrl.text.trim()) ??
                                      0);
                              final frtEgp = (freightType == 'deemed')
                                  ? (double.tryParse(
                                          deemedFreightCtrl.text.trim()) ??
                                      0)
                                  : (double.tryParse(
                                          multiFreightCtrl.text.trim()) ??
                                      0);
                              final addEgp = double.tryParse(
                                      additionalFeesCtrl.text.trim()) ??
                                  0;
                              final cifEgp = double.tryParse(
                                      declaredCifCtrl.text.trim()) ??
                                  (fobEgp + insEgp + frtEgp);

                              final savedPath =
                                  await CustomsPdfService.downloadPdf(
                                currency: selectedCurrency,
                                exchangeRate: rate,
                                totalFobFc: totalFc,
                                totalFobEgp: fobEgp,
                                insuranceEgp: insEgp,
                                freightEgp: frtEgp,
                                additionalFeesEgp: addEgp,
                                totalCifEgp: cifEgp,
                                insuranceMode: insuranceType == 'deemed'
                                    ? (isArabic ? 'حكمي 2.5%' : 'Deemed 2.5%')
                                    : (isArabic ? 'فعلي' : 'Actual'),
                                freightMode: freightType == 'deemed'
                                    ? (isArabic ? 'حكمي 2.0%' : 'Deemed 2.0%')
                                    : (isArabic ? 'فعلي' : 'Actual'),
                                result: multiResult!,
                              );

                              if (savedPath != null && ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        isArabic
                                            ? 'تم حفظ البيان بصيغة PDF بنجاح:\n$savedPath'
                                            : 'Statement saved as PDF successfully:\n$savedPath'),
                                    backgroundColor: AppTheme.emerald,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emerald,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: Text(
                              isArabic ? 'نسخ البيان (Excel)' : 'Copy Statement (Excel)',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              final rate = double.tryParse(
                                      exchangeRateCtrl.text.trim()) ??
                                  _numToDouble(multiResult!['exchange_rate'], 1.0);
                              final totalFc = computeTotalInvoiceFc(multiLines);
                              final fobEgp = totalFc * rate;
                              final insEgp = (insuranceType == 'deemed')
                                  ? (double.tryParse(
                                          deemedInsuranceCtrl.text.trim()) ??
                                      0)
                                  : (double.tryParse(
                                          insuranceCtrl.text.trim()) ??
                                      0);
                              final frtEgp = (freightType == 'deemed')
                                  ? (double.tryParse(
                                          deemedFreightCtrl.text.trim()) ??
                                      0)
                                  : (double.tryParse(
                                          multiFreightCtrl.text.trim()) ??
                                      0);
                              final addEgp = double.tryParse(
                                      additionalFeesCtrl.text.trim()) ??
                                  0;
                              final cifEgp = double.tryParse(
                                      declaredCifCtrl.text.trim()) ??
                                  (fobEgp + insEgp + frtEgp);

                              _copyDutyCalculatorStatement(
                                context,
                                multiLines: multiLines,
                                result: multiResult!,
                                currency: selectedCurrency,
                                exchangeRate: rate,
                                fobEgp: fobEgp,
                                insEgp: insEgp,
                                frtEgp: frtEgp,
                                additionalFeesEgp: addEgp,
                                cifEgp: cifEgp,
                                isArabic: isArabic,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isArabic ? 'إغلاق' : 'Close'),
            ),
          ],
        );
      },
    ),
  ).then((_) {
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
      for (final m in multiLines) {
        (m['value'] as TextEditingController?)?.dispose();
        (m['inspection'] as TextEditingController?)?.dispose();
      }
    });
  }

void _copyDutyCalculatorStatement(
  BuildContext context, {
  required List<Map<String, dynamic>> multiLines,
  required Map<String, dynamic> result,
  required String currency,
  required double exchangeRate,
  required double fobEgp,
  required double insEgp,
  required double frtEgp,
  required double additionalFeesEgp,
  required double cifEgp,
  required bool isArabic,
}) {
  final buffer = StringBuffer();
  if (isArabic) {
    buffer.writeln('بيان احتساب الرسوم والضرائب الجمركية — منصة نافذة');
    buffer.writeln('العملة:\t$currency\tسعر الصرف:\t$exchangeRate');
    buffer.writeln('إجمالي فوب (ج.م):\t${fobEgp.toStringAsFixed(2)}');
    buffer.writeln('التأمين (ج.م):\t${insEgp.toStringAsFixed(2)}');
    buffer.writeln('النولون (ج.م):\t${frtEgp.toStringAsFixed(2)}');
    if (additionalFeesEgp > 0) {
      buffer.writeln('رسوم إضافية (ج.م):\t${additionalFeesEgp.toStringAsFixed(2)}');
    }
    buffer.writeln('القيمة الجمركية سيف (ج.م):\t${cifEgp.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('السطر\tبند التعريفة\tالقيمة سيف (ج.م)\tضريبة الوارد (ج.م)\tضريبة القيمة المضافة (ج.م)\tإجمالي البند (ج.م)');
  } else {
    buffer.writeln('Egyptian Customs Duty & Tax Statement — Nafeza Platform');
    buffer.writeln('Currency:\t$currency\tExchange Rate:\t$exchangeRate');
    buffer.writeln('Total FOB (EGP):\t${fobEgp.toStringAsFixed(2)}');
    buffer.writeln('Insurance (EGP):\t${insEgp.toStringAsFixed(2)}');
    buffer.writeln('Freight (EGP):\t${frtEgp.toStringAsFixed(2)}');
    if (additionalFeesEgp > 0) {
      buffer.writeln('Additional Fees (EGP):\t${additionalFeesEgp.toStringAsFixed(2)}');
    }
    buffer.writeln('Customs Value CIF (EGP):\t${cifEgp.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('Line\tHS Code\tCIF Value (EGP)\tImport Duty (EGP)\tVAT (EGP)\tLine Total (EGP)');
  }

  final items = (result['lines'] as List<dynamic>?) ?? (result['items'] as List<dynamic>?) ?? [];
  for (int i = 0; i < items.length; i++) {
    final item = items[i] as Map<String, dynamic>;
    final lineNum = item['line_no'] ?? (i + 1);
    final hs = item['hs_code'] ?? '';
    final itemCif = _numToDouble(item['cif_value_egp'] ?? item['cif_egp']).toStringAsFixed(2);
    final duty = _numToDouble(item['duty_egp'] ?? item['customs_duty_egp']).toStringAsFixed(2);
    final vat = _numToDouble(item['vat_egp']).toStringAsFixed(2);
    final total = _numToDouble(item['total_line_duties_egp'] ?? item['total_item_taxes_egp'] ?? item['total_duties_and_taxes_egp']).toStringAsFixed(2);
    buffer.writeln('$lineNum\t$hs\t$itemCif\t$duty\t$vat\t$total');
  }

  final feeBreakdown = result['fee_codes_breakdown'] as Map<String, dynamic>?;
  if (feeBreakdown != null) {
    buffer.writeln('');
    buffer.writeln(isArabic ? 'تفاصيل بنود التحصيل:' : 'Fee Codes Breakdown:');
    final fees = feeBreakdown['fees'] as List<dynamic>?;
    if (fees != null) {
      for (final f in fees) {
        final fee = f as Map<String, dynamic>;
        final code = fee['code'] ?? '';
        final name = fee['name'] ?? '';
        final amt = _numToDouble(fee['amount_egp']).toStringAsFixed(2);
        buffer.writeln('$code\t$name\t$amt');
      }
    }
    final grandTotal = _numToDouble(feeBreakdown['grand_total']).toStringAsFixed(2);
    buffer.writeln('${isArabic ? "الإجمالي الكلي" : "Grand Total"}\t\t$grandTotal');
  } else if (result['total_duties_and_taxes_egp'] != null) {
    buffer.writeln('');
    final grandTotal = _numToDouble(result['total_duties_and_taxes_egp']).toStringAsFixed(2);
    buffer.writeln('${isArabic ? "الإجمالي الكلي للرسوم والضرائب (ج.م)" : "Grand Total Duties & Taxes (EGP)"}\t\t$grandTotal');
  }

  CopyHelper.copy(
    context,
    buffer.toString(),
    customMessage: isArabic
        ? 'تم نسخ بيان الرسوم الجمركية بنجاح بصيغة جدول Excel'
        : 'Customs duty statement copied successfully as Excel TSV',
  );
}

double _numToDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? fallback;
  return fallback;
}
