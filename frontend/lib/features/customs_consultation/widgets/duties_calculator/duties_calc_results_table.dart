import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/customs_consultation_model.dart';
import '../tariff_missing_widgets.dart';
import 'duties_calc_row_builder.dart';

/// Detailed Customs Tariff and HS Code line items calculation table.
///
/// Supports itemized vs HS code aggregated grouping, exemption indicators,
/// copyable table cells, and regulatory requirement tags.
class DutiesCalcResultsTable extends StatelessWidget {
  final List<CustomsItemCalcRow> calcLines;
  final bool groupByHsCode;
  final ValueChanged<bool> onGroupByHsCodeChanged;
  final bool hasInvoicesWithoutPoLines;
  final String customsCurrency;

  const DutiesCalcResultsTable({
    super.key,
    required this.calcLines,
    required this.groupByHsCode,
    required this.onGroupByHsCodeChanged,
    required this.hasInvoicesWithoutPoLines,
    required this.customsCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final egpLabel = l.financialSettlementCurrencyEgp;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── TABLE CONTROLS & GROUPING TOGGLE ──────────────────────────────
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              LayoutBuilder(
                builder: (ctx, constraints) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        constraints.maxWidth > 40 ? constraints.maxWidth : 320,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.table_chart,
                        color: AppTheme.cobalt,
                        size: 18,
                      ),
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

          // ── EMPTY / WARNING OR TABLE DATA ──────────────────────────────────
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
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.wcagOrange,
                  ),
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
                rows: calcLines
                    .map(
                      (line) => buildDutiesCalcRow(
                        context: context,
                        line: line,
                        customsCurrency: customsCurrency,
                        egpLabel: egpLabel,
                        isArabic: isArabic,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
