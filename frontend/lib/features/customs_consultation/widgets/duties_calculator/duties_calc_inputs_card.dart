import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../currencies/models/currency_model.dart';
import 'duties_calc_cif_box.dart';
import 'duties_calc_freight_section.dart';
import 'duties_calc_insurance_section.dart';

/// Card containing all valuation parameters, freight costs, marine insurance,
/// and the declared CIF base formula summary.
class DutiesCalcInputsCard extends StatelessWidget {
  final String customsCurrency;
  final ValueChanged<String> onCustomsCurrencyChanged;
  final TextEditingController exchangeRateController;
  final VoidCallback onExchangeRateChanged;
  final DateTime studyDate;
  final ValueChanged<DateTime> onStudyDateChanged;
  final List<CurrencyModel> currenciesList;

  // Ocean Freight Data
  final TextEditingController freightForeignController;
  final String freightCurrency;
  final ValueChanged<String> onFreightCurrencyChanged;
  final TextEditingController freightExchangeRateController;
  final TextEditingController freightEgpController;
  final VoidCallback onRecalculateFreightEgp;
  final int? selectedImportFileId;
  final VoidCallback? onAutoFetchFreightFromScenarios;

  // Marine Insurance Data
  final String insuranceOption;
  final ValueChanged<String> onInsuranceOptionChanged;
  final TextEditingController insuranceEgpController;

  // CIF Base Breakdown Totals
  final double totalFobForeign;
  final double totalFreightEgp;
  final double totalCandFEgp;
  final double totalInsuranceEgp;
  final double totalCifEgp;
  final double totalCifForeign;
  final double? exchangeRate;

  const DutiesCalcInputsCard({
    super.key,
    required this.customsCurrency,
    required this.onCustomsCurrencyChanged,
    required this.exchangeRateController,
    required this.onExchangeRateChanged,
    required this.studyDate,
    required this.onStudyDateChanged,
    required this.currenciesList,
    required this.freightForeignController,
    required this.freightCurrency,
    required this.onFreightCurrencyChanged,
    required this.freightExchangeRateController,
    required this.freightEgpController,
    required this.onRecalculateFreightEgp,
    this.selectedImportFileId,
    this.onAutoFetchFreightFromScenarios,
    required this.insuranceOption,
    required this.onInsuranceOptionChanged,
    required this.insuranceEgpController,
    required this.totalFobForeign,
    required this.totalFreightEgp,
    required this.totalCandFEgp,
    required this.totalInsuranceEgp,
    required this.totalCifEgp,
    required this.totalCifForeign,
    required this.exchangeRate,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ROW 1: VALUATION CURRENCY, FX RATE, STUDY DATE ────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              final currField = SearchableDropdownField<String>(
                value: customsCurrency,
                labelText: l.invoiceCurrencyLabel,
                items: currenciesList.isNotEmpty
                    ? currenciesList
                        .map((c) => SearchableDropdownItem<String>(
                              value: c.currencyCode,
                              label: '${c.currencyCode} - ${c.currencyName}',
                            ))
                        .toList()
                    : const [
                        SearchableDropdownItem(value: 'USD', label: 'USD'),
                        SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                        SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                        SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                        SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                      ],
                onChanged: (v) {
                  if (v != null) onCustomsCurrencyChanged(v);
                },
              );

              final fxField = TextFormField(
                controller: exchangeRateController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.customsFxRateLabel,
                  border: const OutlineInputBorder(),
                  errorText: (double.tryParse(
                                  exchangeRateController.text.trim()) ??
                              0.0) <=
                          0
                      ? l.customsFxRateRequired
                      : null,
                  prefixIcon: const Icon(
                    Icons.currency_exchange,
                    color: AppTheme.cobalt,
                    size: 18,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: l.copyTooltip,
                    onPressed: () {
                      if (exchangeRateController.text.isNotEmpty) {
                        CopyHelper.copy(context, exchangeRateController.text);
                      }
                    },
                  ),
                ),
                onChanged: (_) => onExchangeRateChanged(),
              );

              final dateField = InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: studyDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) onStudyDateChanged(picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l.studyDateLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(
                      Icons.calendar_today,
                      color: AppTheme.cobalt,
                      size: 18,
                    ),
                  ),
                  child: Text(
                    '${studyDate.year}-${studyDate.month.toString().padLeft(2, '0')}-${studyDate.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.charcoal,
                    ),
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    currField,
                    const SizedBox(height: 10),
                    fxField,
                    const SizedBox(height: 10),
                    dateField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 2, child: currField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: fxField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: dateField),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // ── ROW 2: OCEAN FREIGHT DATA ──────────────────────────────────────
          DutiesCalcFreightSection(
            freightForeignController: freightForeignController,
            freightCurrency: freightCurrency,
            onFreightCurrencyChanged: onFreightCurrencyChanged,
            freightExchangeRateController: freightExchangeRateController,
            freightEgpController: freightEgpController,
            onRecalculateFreightEgp: onRecalculateFreightEgp,
            selectedImportFileId: selectedImportFileId,
            onAutoFetchFreightFromScenarios: onAutoFetchFreightFromScenarios,
            currenciesList: currenciesList,
          ),
          const SizedBox(height: 12),

          // ── ROW 3: MARINE INSURANCE VALUATION ──────────────────────────────
          DutiesCalcInsuranceSection(
            insuranceOption: insuranceOption,
            onInsuranceOptionChanged: onInsuranceOptionChanged,
            insuranceEgpController: insuranceEgpController,
          ),
          const SizedBox(height: 14),

          // ── ROW 4: HIGHLIGHTED DECLARED CIF BOX ─────────────────────────────
          DutiesCalcCifBox(
            totalFobForeign: totalFobForeign,
            customsCurrency: customsCurrency,
            totalFreightEgp: totalFreightEgp,
            totalCandFEgp: totalCandFEgp,
            totalInsuranceEgp: totalInsuranceEgp,
            totalCifEgp: totalCifEgp,
            totalCifForeign: totalCifForeign,
            exchangeRate: exchangeRate,
          ),
        ],
      ),
    );
  }
}
