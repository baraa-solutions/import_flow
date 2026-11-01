import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/customs_consultation_model.dart';
import '../tariff_missing_widgets.dart';
import 'consultation_calc_item_row.dart';

/// Table displaying customs tariff line items, HS code details, CIF amounts, and duty/tax rates.
class ConsultationCalcItemsTable extends StatelessWidget {
  final List<CustomsItemCalcRow> calcLines;
  final String customsCurrency;
  final bool groupByHsCode;
  final ValueChanged<bool> onGroupByHsCodeChanged;
  final bool hasInvoicesWithoutPoLines;
  final VoidCallback onSyncHsRequirementsToChecklist;

  const ConsultationCalcItemsTable({
    super.key,
    required this.calcLines,
    required this.customsCurrency,
    required this.groupByHsCode,
    required this.onGroupByHsCodeChanged,
    required this.hasInvoicesWithoutPoLines,
    required this.onSyncHsRequirementsToChecklist,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final egpLabel = l.financialSettlementCurrencyEgp;

    return SelectionArea(
      child: Card(
        elevation: 2,
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Table Toolbar & Grouping Toggle
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.table_chart,
                          color: AppTheme.cobalt, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l.tariffDetailsTableTitle(
                          calcLines.length,
                          groupByHsCode
                              ? l.groupedHsCodeItems
                              : l.detailedItems,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.charcoal,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppButton(
                        label: l.syncHsRequirementsToChecklist,
                        icon: Icons.sync_alt,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: onSyncHsRequirementsToChecklist,
                      ),
                      const SizedBox(width: 8),
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
                ],
              ),
              const Divider(height: 20),

              // Empty or Warning States
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
                  count:
                      calcLines.where((line) => line.isTariffMissing).length,
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
                      DataColumn(
                          label: Text(l.valueInCurrencyCol(customsCurrency))),
                      DataColumn(label: Text(l.fobEgpCol)),
                      DataColumn(label: Text(l.cifEgpCol)),
                      DataColumn(label: Text(l.customsDutyCol)),
                      DataColumn(label: Text(l.vatCol)),
                      DataColumn(label: Text(l.otherTaxesCol)),
                      DataColumn(label: Text(l.totalTaxesAndDutiesCol)),
                      DataColumn(label: Text(l.regulatoryRequirementsCol)),
                    ],
                    rows: calcLines
                        .map(
                          (line) => ConsultationCalcItemRow.buildRow(
                            context: context,
                            line: line,
                            customsCurrency: customsCurrency,
                            l: l,
                            isArabic: isArabic,
                            egpLabel: egpLabel,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
