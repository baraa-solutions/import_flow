import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../currencies/models/currency_model.dart';
import '../models/customs_consultation_model.dart';
import 'duties_calculator/duties_calculator.dart';
import 'nafeza_fee_breakdown_card.dart';
import 'recalculation_variance_comparison_card.dart';

/// Customs Duties & Landed-Cost Calculator Tab Coordinator.
///
/// Encapsulates the customs tariff calculation engine (MD-008 Customs Engine),
/// delegating modular concerns to [DutiesCalcHeader], [DutiesCalcInputsCard],
/// [DutiesCalcResultsTable], [DutiesCalcTaxesCard], [DutiesCalcActionsBar],
/// and [NafezaFeeBreakdownCard].
class CustomsDutiesCalculatorTab extends StatelessWidget {
  final bool isTaxReviewMode;
  final String customsCurrency;
  final ValueChanged<String> onCustomsCurrencyChanged;
  final TextEditingController exchangeRateController;
  final VoidCallback onExchangeRateChanged;
  final DateTime studyDate;
  final ValueChanged<DateTime> onStudyDateChanged;
  final List<CurrencyModel> currenciesList;

  // Freight & Insurance
  final TextEditingController freightForeignController;
  final String freightCurrency;
  final ValueChanged<String> onFreightCurrencyChanged;
  final TextEditingController freightExchangeRateController;
  final TextEditingController freightEgpController;
  final VoidCallback onRecalculateFreightEgp;
  final int? selectedImportFileId;
  final VoidCallback? onAutoFetchFreightFromScenarios;
  final String insuranceOption;
  final ValueChanged<String> onInsuranceOptionChanged;
  final TextEditingController insuranceEgpController;

  // Valuation totals
  final double totalFobForeign;
  final double totalFobEgp;
  final double totalCandFEgp;
  final double totalFreightEgp;
  final double totalInsuranceEgp;
  final double totalCifEgp;
  final double totalCifForeign;
  final double? exchangeRate;

  // Calculation lines
  final List<CustomsItemCalcRow> calcLines;
  final bool groupByHsCode;
  final ValueChanged<bool> onGroupByHsCodeChanged;

  // Recalculation
  final CustomsRecalculationResponseModel? recalculationResult;
  final TextEditingController? preliminaryRateController;
  final VoidCallback? onApplyNewFees;
  final VoidCallback? onCloseRecalculation;

  // State flags & Actions
  final bool hasInvoicesWithoutPoLines;
  final bool isCustomsCalculatorExpanded;
  final VoidCallback onToggleCustomsCalculatorExpanded;
  final bool isRecalculating;
  final VoidCallback? onFetchReconciledFinalInvoice;
  final VoidCallback onSyncHsRequirementsToChecklist;

  // Engine Summary
  final double totalDutyEgp;
  final double totalVatEgp;
  final double totalTaxesAndDutiesEgp;
  final double? engineGrandTotal;
  final bool isEstimatingDuty;
  final VoidCallback onApplyAndLinkFinancialEstimate;

  // Nafeza Fee Breakdown Context
  final int? editingConsultationId;
  final String? editingConsultationCode;
  final int? selectedBrokerId;
  final String selectedBrokerName;
  final String title;
  final List<CustomsChecklistItemModel> checklist;
  final List<CustomsBrokerQuoteItemModel> brokerQuoteItems;

  const CustomsDutiesCalculatorTab({
    super.key,
    required this.isTaxReviewMode,
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
    required this.totalFobEgp,
    required this.totalCandFEgp,
    required this.totalFreightEgp,
    required this.totalInsuranceEgp,
    required this.totalCifEgp,
    required this.totalCifForeign,
    required this.exchangeRate,
    required this.calcLines,
    required this.groupByHsCode,
    required this.onGroupByHsCodeChanged,
    this.recalculationResult,
    this.preliminaryRateController,
    this.onApplyNewFees,
    this.onCloseRecalculation,
    required this.hasInvoicesWithoutPoLines,
    required this.isCustomsCalculatorExpanded,
    required this.onToggleCustomsCalculatorExpanded,
    this.isRecalculating = false,
    this.onFetchReconciledFinalInvoice,
    required this.onSyncHsRequirementsToChecklist,
    required this.totalDutyEgp,
    required this.totalVatEgp,
    required this.totalTaxesAndDutiesEgp,
    this.engineGrandTotal,
    this.isEstimatingDuty = false,
    required this.onApplyAndLinkFinancialEstimate,
    this.editingConsultationId,
    this.editingConsultationCode,
    this.selectedBrokerId,
    required this.selectedBrokerName,
    required this.title,
    required this.checklist,
    required this.brokerQuoteItems,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: Card(
        elevation: 3,
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DutiesCalcHeader(
                isTaxReviewMode: isTaxReviewMode,
                isRecalculating: isRecalculating,
                onFetchReconciledFinalInvoice: onFetchReconciledFinalInvoice,
                onSyncHsRequirementsToChecklist:
                    onSyncHsRequirementsToChecklist,
                isCustomsCalculatorExpanded: isCustomsCalculatorExpanded,
                onToggleCustomsCalculatorExpanded:
                    onToggleCustomsCalculatorExpanded,
              ),
              if (isCustomsCalculatorExpanded) ...[
                const Divider(height: 24),
                DutiesCalcInputsCard(
                  customsCurrency: customsCurrency,
                  onCustomsCurrencyChanged: onCustomsCurrencyChanged,
                  exchangeRateController: exchangeRateController,
                  onExchangeRateChanged: onExchangeRateChanged,
                  studyDate: studyDate,
                  onStudyDateChanged: onStudyDateChanged,
                  currenciesList: currenciesList,
                  freightForeignController: freightForeignController,
                  freightCurrency: freightCurrency,
                  onFreightCurrencyChanged: onFreightCurrencyChanged,
                  freightExchangeRateController: freightExchangeRateController,
                  freightEgpController: freightEgpController,
                  onRecalculateFreightEgp: onRecalculateFreightEgp,
                  selectedImportFileId: selectedImportFileId,
                  onAutoFetchFreightFromScenarios:
                      onAutoFetchFreightFromScenarios,
                  insuranceOption: insuranceOption,
                  onInsuranceOptionChanged: onInsuranceOptionChanged,
                  insuranceEgpController: insuranceEgpController,
                  totalFobForeign: totalFobForeign,
                  totalFreightEgp: totalFreightEgp,
                  totalCandFEgp: totalCandFEgp,
                  totalInsuranceEgp: totalInsuranceEgp,
                  totalCifEgp: totalCifEgp,
                  totalCifForeign: totalCifForeign,
                  exchangeRate: exchangeRate,
                ),
                const SizedBox(height: 10),
                if (recalculationResult != null) ...[
                  if (recalculationResult!.hasDifferentCurrencies &&
                      preliminaryRateController != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 320,
                      child: TextFormField(
                        controller: preliminaryRateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              '${l.ccPreliminaryRateLabel} (${recalculationResult!.preliminaryCurrency} → EGP)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  RecalculationVarianceComparisonCard(
                    recalculationResult: recalculationResult!,
                    onApplyNewFees: onApplyNewFees ?? () {},
                    onClose: onCloseRecalculation ?? () {},
                  ),
                ],
                const SizedBox(height: 10),
                DutiesCalcResultsTable(
                  calcLines: calcLines,
                  groupByHsCode: groupByHsCode,
                  onGroupByHsCodeChanged: onGroupByHsCodeChanged,
                  hasInvoicesWithoutPoLines: hasInvoicesWithoutPoLines,
                  customsCurrency: customsCurrency,
                ),
                const SizedBox(height: 14),
                DutiesCalcTaxesCard(calcLines: calcLines),
                const SizedBox(height: 16),
                DutiesCalcActionsBar(
                  customsCurrency: customsCurrency,
                  totalFobForeign: totalFobForeign,
                  totalFobEgp: totalFobEgp,
                  totalCifForeign: totalCifForeign,
                  totalCifEgp: totalCifEgp,
                  totalDutyEgp: totalDutyEgp,
                  totalVatEgp: totalVatEgp,
                  totalTaxesAndDutiesEgp: totalTaxesAndDutiesEgp,
                  engineGrandTotal: engineGrandTotal,
                  isEstimatingDuty: isEstimatingDuty,
                  onApplyAndLinkFinancialEstimate:
                      onApplyAndLinkFinancialEstimate,
                ),
                const SizedBox(height: 16),
                NafezaFeeBreakdownCard(
                  calcLines: calcLines,
                  totalDutyEgp: totalDutyEgp,
                  totalVatEgp: totalVatEgp,
                  totalServiceFeeEgp: calcLines.fold(
                    0.0,
                    (s, line) => s + line.customsServiceFeeAmountEgp,
                  ),
                  totalScheduleTaxEgp: calcLines.fold(
                    0.0,
                    (s, line) => s + line.scheduleTaxAmountEgp,
                  ),
                  totalFreightEgp: totalFreightEgp,
                  totalInsuranceEgp: totalInsuranceEgp,
                  exchangeRate: exchangeRate ?? 0.0,
                  editingConsultationId: editingConsultationId,
                  editingConsultationCode: editingConsultationCode,
                  selectedBrokerId: selectedBrokerId,
                  selectedBrokerName: selectedBrokerName,
                  title: title,
                  checklist: checklist,
                  brokerQuoteItems: brokerQuoteItems,
                  selectedImportFileId: selectedImportFileId,
                  customsCurrency: customsCurrency,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
