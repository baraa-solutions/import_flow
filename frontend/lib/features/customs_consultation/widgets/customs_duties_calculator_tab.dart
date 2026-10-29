import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../currencies/models/currency_model.dart';
import '../models/customs_consultation_model.dart';
import 'consultation_metric_badge.dart';
import 'nafeza_fee_breakdown_card.dart';
import 'recalculation_variance_comparison_card.dart';
import 'tariff_missing_widgets.dart';

/// Customs Duties & Landed-Cost Calculator Tab / Engine Card.
///
/// Encapsulates the customs tariff calculation engine (MD-008 Customs Engine),
/// including official exchange rates, freight & marine insurance valuation,
/// CIF base decomposition, HS code line items breakdown, exemption notices,
/// and the official Nafeza fees schedule.
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final egpLabel = context.l10n.financialSettlementCurrencyEgp;

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
              // ── CARD HEADER & TOOLBAR ─────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 750;
                  final titleWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calculate,
                          color: AppTheme.cobalt, size: 22),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.customsCalculationEngine,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.charcoal,
                              ),
                            ),
                            Text(
                              l.customsCalculationEngineSub,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final actionButtons = <Widget>[
                    if (isTaxReviewMode) ...[
                      AppButton(
                        label: l.fetchReconciledFinalInvoice,
                        icon: Icons.flash_on,
                        variant: AppButtonVariant.success,
                        size: AppButtonSize.small,
                        isLoading: isRecalculating,
                        onPressed: isRecalculating
                            ? null
                            : onFetchReconciledFinalInvoice,
                      ),
                    ],
                    AppButton(
                      label: l.syncHsRequirementsToChecklist,
                      icon: Icons.sync_alt,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      onPressed: onSyncHsRequirementsToChecklist,
                    ),
                    IconButton(
                      icon: Icon(
                        isCustomsCalculatorExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.charcoal,
                      ),
                      tooltip: l.view,
                      onPressed: onToggleCustomsCalculatorExpanded,
                    ),
                  ];

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleWidget,
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: actionButtons,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: titleWidget),
                      ...actionButtons.map((w) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: w,
                          )),
                    ],
                  );
                },
              ),

              if (isCustomsCalculatorExpanded) ...[
                const Divider(height: 24),

                // ── ROW 1: VALUATION CURRENCY, FX RATE, STUDY DATE ──────────
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
                                    label:
                                        '${c.currencyCode} - ${c.currencyName}',
                                  ))
                              .toList()
                          : const [
                              SearchableDropdownItem(
                                  value: 'USD', label: 'USD'),
                              SearchableDropdownItem(
                                  value: 'EUR', label: 'EUR'),
                              SearchableDropdownItem(
                                  value: 'GBP', label: 'GBP'),
                              SearchableDropdownItem(
                                  value: 'CNY', label: 'CNY'),
                              SearchableDropdownItem(
                                  value: 'EGP', label: 'EGP'),
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
                        prefixIcon: const Icon(Icons.currency_exchange,
                            color: AppTheme.cobalt, size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: l.copyTooltip,
                          onPressed: () {
                            if (exchangeRateController.text.isNotEmpty) {
                              CopyHelper.copy(
                                  context, exchangeRateController.text);
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
                          prefixIcon: const Icon(Icons.calendar_today,
                              color: AppTheme.cobalt, size: 18),
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

                // ── ROW 2: OCEAN FREIGHT DATA ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.cobalt.withValues(alpha: 0.12)
                        : AppTheme.cobaltLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.cobalt.withValues(alpha: 0.3)
                          : AppTheme.cobaltBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_boat,
                              color: AppTheme.cobalt, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l.freightDataHeader,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.charcoal,
                              ),
                            ),
                          ),
                          if (selectedImportFileId != null &&
                              onAutoFetchFreightFromScenarios != null)
                            AppButton(
                              label: l.fetchHighestFreightFromStudy,
                              icon: Icons.download,
                              variant: AppButtonVariant.secondary,
                              size: AppButtonSize.small,
                              onPressed: onAutoFetchFreightFromScenarios,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 700;
                          final fAmount = TextFormField(
                            controller: freightForeignController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l.foreignFreightAmountLabel,
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                tooltip: l.copyTooltip,
                                onPressed: () {
                                  if (freightForeignController.text.isNotEmpty) {
                                    CopyHelper.copy(context,
                                        freightForeignController.text);
                                  }
                                },
                              ),
                            ),
                            onChanged: (_) => onRecalculateFreightEgp(),
                          );

                          final fCurr = SearchableDropdownField<String>(
                            value: freightCurrency,
                            labelText: l.freightCurrencyLabel,
                            items: currenciesList.isNotEmpty
                                ? currenciesList
                                    .map((c) => SearchableDropdownItem<String>(
                                          value: c.currencyCode,
                                          label:
                                              '${c.currencyCode} - ${c.currencyName}',
                                        ))
                                    .toList()
                                : const [
                                    SearchableDropdownItem(
                                        value: 'USD', label: 'USD'),
                                    SearchableDropdownItem(
                                        value: 'EUR', label: 'EUR'),
                                    SearchableDropdownItem(
                                        value: 'GBP', label: 'GBP'),
                                    SearchableDropdownItem(
                                        value: 'EGP', label: 'EGP'),
                                  ],
                            onChanged: (v) {
                              if (v != null) onFreightCurrencyChanged(v);
                            },
                          );

                          final fFx = TextFormField(
                            controller: freightExchangeRateController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l.freightFxRateLabel,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.currency_exchange,
                                  color: AppTheme.cobalt, size: 16),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                tooltip: l.copyTooltip,
                                onPressed: () {
                                  if (freightExchangeRateController
                                      .text.isNotEmpty) {
                                    CopyHelper.copy(context,
                                        freightExchangeRateController.text);
                                  }
                                },
                              ),
                            ),
                            onChanged: (_) => onRecalculateFreightEgp(),
                          );

                          final fEgp = TextFormField(
                            controller: freightEgpController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText:
                                  '${l.freightEgpLabel} ($egpLabel)',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.attach_money,
                                  color: AppTheme.emerald, size: 18),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                tooltip: l.copyTooltip,
                                onPressed: () {
                                  if (freightEgpController.text.isNotEmpty) {
                                    CopyHelper.copy(
                                        context, freightEgpController.text);
                                  }
                                },
                              ),
                            ),
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                fAmount,
                                const SizedBox(height: 8),
                                fCurr,
                                const SizedBox(height: 8),
                                fFx,
                                const SizedBox(height: 8),
                                fEgp,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(flex: 2, child: fAmount),
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: fCurr),
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: fFx),
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: fEgp),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── ROW 3: MARINE INSURANCE VALUATION ────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.orange.withValues(alpha: 0.12)
                        : AppTheme.orangeLight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.orange.withValues(alpha: 0.3)
                          : AppTheme.orange,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.security,
                              color: AppTheme.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.estimatedCustomsInsuranceRateLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.charcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SegmentedButton<String>(
                            segments: [
                              ButtonSegment(
                                  value: '0.5%',
                                  label: Text(l.standardCustomsInsuranceRate)),
                              const ButtonSegment(
                                  value: '1.0%', label: Text('1.0%')),
                              ButtonSegment(
                                  value: 'Custom',
                                  label: Text(l.customInsuranceRate)),
                            ],
                            selected: {insuranceOption},
                            onSelectionChanged: (set) {
                              onInsuranceOptionChanged(set.first);
                            },
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          SizedBox(
                            width: 320,
                            child: TextFormField(
                              controller: insuranceEgpController,
                              readOnly: insuranceOption != 'Custom',
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText:
                                    '${l.insuranceEgpLabel} ($egpLabel)',
                                border: const OutlineInputBorder(),
                                filled: insuranceOption != 'Custom',
                                fillColor: insuranceOption != 'Custom'
                                    ? (isDark
                                        ? AppTheme.darkElevatedSurface
                                        : AppTheme.charcoalSurface)
                                    : null,
                                helperText: insuranceOption != 'Custom'
                                    ? l.autoCalculatedCandFInsuranceHelper(
                                        insuranceOption)
                                    : null,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l.copyTooltip,
                                  onPressed: () {
                                    if (insuranceEgpController
                                        .text.isNotEmpty) {
                                      CopyHelper.copy(context,
                                          insuranceEgpController.text);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── ROW 4: HIGHLIGHTED DECLARED CIF BOX ───────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isDark
                            ? AppTheme.darkElevatedSurface
                            : AppTheme.charcoal.withValues(alpha: 0.04),
                        AppTheme.emerald
                            .withValues(alpha: isDark ? 0.15 : 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.emerald.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 600;
                      final infoCol = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified,
                                  color: AppTheme.emerald, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l.declaredCifBaseLabel,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppTheme.darkTextPrimary
                                        : AppTheme.charcoal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.cifFormulaBreakdown(
                              totalFobForeign.toStringAsFixed(2),
                              customsCurrency,
                              totalFreightEgp.toStringAsFixed(2),
                              totalCandFEgp.toStringAsFixed(2),
                              totalInsuranceEgp.toStringAsFixed(2),
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textStrong,
                            ),
                          ),
                        ],
                      );

                      final numbersCol = Column(
                        crossAxisAlignment: isNarrow
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.end,
                        children: [
                          CopyableText(
                            '${totalCifEgp.toStringAsFixed(2)} $egpLabel',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.emerald,
                            ),
                          ),
                          if (exchangeRate != null && exchangeRate! > 0)
                            CopyableText(
                              '≈ ${totalCifForeign.toStringAsFixed(2)} $customsCurrency',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.cobalt,
                              ),
                            ),
                        ],
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            infoCol,
                            const SizedBox(height: 10),
                            numbersCol,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: infoCol),
                          numbersCol,
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // ── ROW 5: TABLE CONTROLS & GROUPING TOGGLE ──────────────────
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    LayoutBuilder(
                      builder: (ctx, constraints) => ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth > 40
                                ? constraints.maxWidth
                                : 320),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.table_chart,
                                color: AppTheme.cobalt, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                l.tariffDetailsTableTitle(
                                  calcLines.length,
                                  groupByHsCode
                                      ? l.groupedHsCodeItems
                                      : l.detailedItems,
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.charcoal,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FilterChip(
                      selected: groupByHsCode,
                      label: Text(
                        groupByHsCode
                            ? l.groupByHsCodeOption
                            : l.detailedItemViewOption,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: groupByHsCode
                              ? AppTheme.white
                              : (isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.charcoal),
                        ),
                      ),
                      selectedColor: AppTheme.cobalt,
                      checkmarkColor: AppTheme.white,
                      onSelected: onGroupByHsCodeChanged,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── RECALCULATION VARIANCE CARD (IF PRESENT) ─────────────────
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

                // ── HS CODE LINES CALCULATION TABLE ─────────────────────────
                if (hasInvoicesWithoutPoLines) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.orangeLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppTheme.wcagOrange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.addPoLinesWithHsToEstimateDuties,
                            style: const TextStyle(
                              color: AppTheme.wcagOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (calcLines.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cobaltLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.cobalt),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.noResultsFound,
                            style: const TextStyle(
                              color: AppTheme.charcoal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  TariffMissingBanner(
                    count: calcLines.where((line) => line.isTariffMissing).length,
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 14,
                      headingRowColor: WidgetStateProperty.all(
                        AppTheme.charcoal.withValues(alpha: 0.06),
                      ),
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.charcoal,
                        fontSize: 12,
                      ),
                      columns: [
                        DataColumn(label: Text(l.actionsCol)),
                        DataColumn(label: Text(l.customsTariffItemCol)),
                        DataColumn(label: Text(l.itemDescriptionAndOriginCol)),
                        DataColumn(label: Text(l.quantityAndUnitCol)),
                        DataColumn(label: Text(l.valueInCurrencyCol(customsCurrency))),
                        DataColumn(label: Text(l.fobEgpCol)),
                        DataColumn(label: Text(l.cifEgpCol)),
                        DataColumn(label: Text(l.customsDutyCol)),
                        DataColumn(label: Text(l.vatCol)),
                        DataColumn(label: Text(l.otherTaxesCol)),
                        DataColumn(label: Text(l.totalTaxesAndDutiesCol)),
                        DataColumn(label: Text(l.regulatoryRequirementsCol)),
                      ],
                      rows: calcLines.map((line) {
                        final rowSummary = isArabic
                            ? '${line.hsCode} | ${line.description} | ${l.quantityAndUnitCol}: ${line.qty.toStringAsFixed(0)} ${line.unit} | ${l.fobEgpCol}: ${line.fobEgp.toStringAsFixed(2)} $egpLabel | ${l.cifEgpCol}: ${line.cifEgp.toStringAsFixed(2)} $egpLabel | ${l.customsDutyCol}: ${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)} $egpLabel) | ${l.vatCol}: ${line.vatRate}% (${line.vatAmountEgp.toStringAsFixed(2)} $egpLabel) | ${l.totalTaxesAndDutiesCol}: ${line.totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel'
                            : '${line.hsCode} | ${line.description} | Qty: ${line.qty.toStringAsFixed(0)} ${line.unit} | FOB: ${line.fobEgp.toStringAsFixed(2)} $egpLabel | CIF: ${line.cifEgp.toStringAsFixed(2)} $egpLabel | Duty: ${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)} $egpLabel) | VAT: ${line.vatRate}% (${line.vatAmountEgp.toStringAsFixed(2)} $egpLabel) | Total: ${line.totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel';
                        return DataRow(
                          cells: [
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.copy,
                                    size: 16, color: AppTheme.cobalt),
                                tooltip: l.copyTooltip,
                                onPressed: () => CopyHelper.copy(
                                  context,
                                  rowSummary,
                                  customMessage: l.customsTaxCopyRowSuccess,
                                ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: line.hsCode,
                                rowSummary: rowSummary,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cobalt
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        line.hsCode,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.cobalt,
                                        ),
                                      ),
                                    ),
                                    if (line.isTariffMissing) ...[
                                      const SizedBox(width: 4),
                                      const TariffMissingBadge(),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value:
                                    '${line.description}${line.countryOfOrigin != null ? " (${line.countryOfOrigin})" : ""}',
                                rowSummary: rowSummary,
                                child: SizedBox(
                                  width: 190,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        line.description,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      if (line.countryOfOrigin != null &&
                                          line.countryOfOrigin!.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cobaltLight,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: AppTheme.cobaltBorder),
                                          ),
                                          child: Text(
                                            line.countryOfOrigin!,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.wcagCobalt,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value:
                                    '${line.qty.toStringAsFixed(0)} ${line.unit}',
                                rowSummary: rowSummary,
                                child: Text(
                                    '${line.qty.toStringAsFixed(0)} ${line.unit}'),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value:
                                    '${line.foreignPrice.toStringAsFixed(2)} $customsCurrency',
                                rowSummary: rowSummary,
                                child: Text(
                                  '${line.foreignPrice.toStringAsFixed(2)} $customsCurrency',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.cobalt,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: !line.isCalculated
                                    ? '—'
                                    : '${line.fobEgp.toStringAsFixed(2)} $egpLabel',
                                rowSummary: rowSummary,
                                child: Text(!line.isCalculated
                                    ? '—'
                                    : line.fobEgp.toStringAsFixed(2)),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: !line.isCalculated
                                    ? '—'
                                    : '${line.cifEgp.toStringAsFixed(2)} $egpLabel',
                                rowSummary: rowSummary,
                                child: Text(
                                  !line.isCalculated
                                      ? '—'
                                      : line.cifEgp.toStringAsFixed(2),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: !line.isCalculated
                                    ? '—'
                                    : '${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)} $egpLabel)',
                                rowSummary: rowSummary,
                                child: !line.isCalculated
                                    ? const Text('—',
                                        style: TextStyle(
                                          color: AppTheme.textMuted,
                                          fontWeight: FontWeight.bold,
                                        ))
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (line.hasExemption) ...[
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${line.baseDutyRate}%',
                                                  style: const TextStyle(
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                    color: AppTheme.textMuted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)})',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.emerald,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              margin:
                                                  const EdgeInsets.only(top: 2),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppTheme.emeraldLight,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                    color:
                                                        AppTheme.emeraldBorder),
                                              ),
                                              child: Text(
                                                line.appliedAgreementName ??
                                                    (context.l10n.ccExemption),
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  color: AppTheme.wcagEmerald,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ] else ...[
                                            Text(
                                                '${line.dutyRate}% (${line.dutyAmountEgp.toStringAsFixed(2)})'),
                                          ],
                                        ],
                                      ),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: !line.isCalculated
                                    ? '—'
                                    : '${line.vatRate}% (${line.vatAmountEgp.toStringAsFixed(2)} $egpLabel)',
                                rowSummary: rowSummary,
                                child: !line.isCalculated
                                    ? const Text('—',
                                        style: TextStyle(
                                          color: AppTheme.textMuted,
                                          fontWeight: FontWeight.bold,
                                        ))
                                    : Text(
                                        '${line.vatRate}% (${line.vatAmountEgp.toStringAsFixed(2)})'),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: !line.isCalculated
                                    ? '—'
                                    : '${(line.scheduleTaxAmountEgp + line.developmentFeeAmountEgp + line.customsServiceFeeAmountEgp).toStringAsFixed(2)} $egpLabel',
                                rowSummary: rowSummary,
                                child: !line.isCalculated
                                    ? const Text('—',
                                        style: TextStyle(
                                          color: AppTheme.textMuted,
                                          fontWeight: FontWeight.bold,
                                        ))
                                    : Text(
                                        '${(line.scheduleTaxAmountEgp + line.developmentFeeAmountEgp + line.customsServiceFeeAmountEgp).toStringAsFixed(2)} $egpLabel'),
                              ),
                            ),
                            DataCell(
                              CopyableTableCell(
                                value: !line.isCalculated
                                    ? '—'
                                    : '${line.totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel',
                                rowSummary: rowSummary,
                                child: !line.isCalculated
                                    ? const Text('—',
                                        style: TextStyle(
                                          color: AppTheme.textMuted,
                                          fontWeight: FontWeight.bold,
                                        ))
                                    : Text(
                                        '${line.totalTaxesAndDutiesEgp.toStringAsFixed(2)} $egpLabel',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.crimson,
                                        ),
                                      ),
                              ),
                            ),
                            DataCell(
                              line.isTariffMissing
                                  ? const TariffMissingBadge()
                                  : !line.isCalculated
                                      ? const Text('—',
                                          style: TextStyle(
                                            color: AppTheme.textMuted,
                                            fontWeight: FontWeight.bold,
                                          ))
                                      : Row(
                                          children: [
                                            if (line.requiresAcid)
                                              Container(
                                                margin:
                                                    const EdgeInsetsDirectional
                                                        .only(start: 4),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.cobaltBorder,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  context.l10n.ccACID,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.cobalt,
                                                  ),
                                                ),
                                              ),
                                            if (line.requiresCoo)
                                              Container(
                                                margin:
                                                    const EdgeInsetsDirectional
                                                        .only(start: 4),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.emeraldBorder,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  context.l10n.ccCOO,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.emerald,
                                                  ),
                                                ),
                                              ),
                                            if (line.requiresInspection)
                                              Container(
                                                margin:
                                                    const EdgeInsetsDirectional
                                                        .only(start: 4),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.orangeLight,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  context.l10n.ccGOEIC,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.orange,
                                                  ),
                                                ),
                                              ),
                                            if (line.regulatoryAuthority !=
                                                null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.cobaltLight,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  line.regulatoryAuthority!,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.cobalt,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── EXEMPTIONS & REGULATORY REQUIREMENTS NOTICES ───────────
                  ...calcLines
                      .where((l) =>
                          l.hasExemption ||
                          l.priorApprovalNote != null ||
                          (l.regulatoryAuthority != null &&
                              l.regulatoryAuthority!.isNotEmpty))
                      .map((line) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppTheme.wcagOrange, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppTheme.wcagOrange, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${context.l10n.ccHSCode}: ${line.hsCode}${line.countryOfOrigin != null ? " - ${line.countryOfOrigin}" : ""}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.wcagOrange,
                                  ),
                                ),
                              ),
                              if (line.hasExemption)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emeraldBorder,
                                    borderRadius: BorderRadius.circular(4),
                                    border:
                                        Border.all(color: AppTheme.wcagEmerald),
                                  ),
                                  child: Text(
                                    line.appliedAgreementName ??
                                        (context.l10n.ccExemption),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.wcagEmerald,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (line.exemptionConditionsNote != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              line.exemptionConditionsNote!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.charcoal,
                              ),
                            ),
                          ],
                          if (line.requiredDocument != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              line.requiredDocument!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.wcagCobalt,
                              ),
                            ),
                          ],
                          if (line.priorApprovalNote != null &&
                              line.priorApprovalNote!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              line.priorApprovalNote!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.charcoal,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // ── FINANCIAL SUMMARY METRIC MATRIX ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.charcoal.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.cobalt.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConsultationMetricBadge(
                          title: l.fobEgpCol,
                          value:
                              '${totalFobForeign.toStringAsFixed(2)} $customsCurrency\n(${totalFobEgp.toStringAsFixed(2)} $egpLabel)',
                          color: AppTheme.charcoal,
                        ),
                        ConsultationMetricBadge(
                          title: l.cifEgpCol,
                          value:
                              '${totalCifForeign.toStringAsFixed(2)} $customsCurrency\n(${totalCifEgp.toStringAsFixed(2)} $egpLabel)',
                          color: AppTheme.cobalt,
                        ),
                        ConsultationMetricBadge(
                          title: l.customsDutyCol,
                          value: '${totalDutyEgp.toStringAsFixed(2)} $egpLabel',
                          color: AppTheme.cobalt,
                        ),
                        ConsultationMetricBadge(
                          title: l.vatCol,
                          value: '${totalVatEgp.toStringAsFixed(2)} $egpLabel',
                          color: AppTheme.emerald,
                        ),
                        ConsultationMetricBadge(
                          title: l.totalTaxesAndDutiesCol,
                          value:
                              '${(engineGrandTotal ?? totalTaxesAndDutiesEgp).toStringAsFixed(2)} $egpLabel',
                          color: AppTheme.crimson,
                        ),
                        if (isEstimatingDuty)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.cobalt,
                              ),
                            ),
                          ),
                        AppButton(
                          label: l.applyAndLinkFinancialEstimate,
                          icon: Icons.done_all,
                          variant: AppButtonVariant.success,
                          size: AppButtonSize.small,
                          onPressed: onApplyAndLinkFinancialEstimate,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── NAFEZA STATEMENT FEE BREAKDOWN CARD ────────────────────
                  NafezaFeeBreakdownCard(
                    calcLines: calcLines,
                    totalDutyEgp: totalDutyEgp,
                    totalVatEgp: totalVatEgp,
                    totalServiceFeeEgp: calcLines.fold(
                        0.0, (s, line) => s + line.customsServiceFeeAmountEgp),
                    totalScheduleTaxEgp: calcLines.fold(
                        0.0, (s, line) => s + line.scheduleTaxAmountEgp),
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
            ],
          ),
        ),
      ),
    );
  }
}
