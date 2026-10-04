import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/customs_consultation_model.dart';

class RecalculationVarianceComparisonCard extends StatelessWidget {
  final CustomsRecalculationResponseModel recalculationResult;
  final VoidCallback onApplyNewFees;
  final VoidCallback onClose;

  const RecalculationVarianceComparisonCard({
    super.key,
    required this.recalculationResult,
    required this.onApplyNewFees,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final res = recalculationResult;
    final isIncrease = res.totalTaxesVarianceEgp > 0;
    final isDecrease = res.totalTaxesVarianceEgp < 0;

    final statusColor = isIncrease
        ? AppTheme.crimson
        : (isDecrease ? AppTheme.emerald : AppTheme.cobalt);

    final statusText = isIncrease
        ? '+${res.totalTaxesVarianceEgp.toStringAsFixed(2)} EGP'
        : (isDecrease
            ? '${res.totalTaxesVarianceEgp.toStringAsFixed(2)} EGP'
            : '0.00 EGP');

    final statusIcon = isIncrease
        ? Icons.trending_up
        : (isDecrease ? Icons.trending_down : Icons.check_circle);

    return Card(
      elevation: 4,
      color: isDark ? AppTheme.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER WITH BADGE ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.customsCalculationEngine,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${res.sourceDescription} | ${res.finalInvoiceNumber ?? "N/A"} | ${res.estimateDate} | ${res.exchangeRate.toStringAsFixed(4)} EGP',
                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? AppTheme.darkTextSecondary : Colors.grey, size: 20),
                  tooltip: l.close,
                  onPressed: onClose,
                ),
              ],
            ),
            const Divider(height: 24),

            // ── 4 KPI COMPARISON SUMMARY CARDS ─────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final kpi1 = _buildKpiCard(
                  context: context,
                  title: l.fobEgpCol,
                  preliminaryVal: res.preliminaryFobEgp,
                  finalVal: res.finalFobEgp,
                  varianceVal: res.fobVarianceEgp,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                );
                final kpi2 = _buildKpiCard(
                  context: context,
                  title: l.cifEgpCol,
                  preliminaryVal: res.preliminaryCifEgp,
                  finalVal: res.finalCifEgp,
                  varianceVal: res.cifVarianceEgp,
                  color: AppTheme.cobalt,
                );
                final kpi3 = _buildKpiCard(
                  context: context,
                  title: l.customsDutyCol,
                  preliminaryVal: res.preliminaryDutyEgp,
                  finalVal: res.finalDutyEgp,
                  varianceVal: res.dutyVarianceEgp,
                  color: Colors.indigo,
                );
                final kpi4 = _buildKpiCard(
                  context: context,
                  title: l.totalTaxesAndDutiesCol,
                  preliminaryVal: res.preliminaryTotalTaxesEgp,
                  finalVal: res.finalTotalTaxesEgp,
                  varianceVal: res.totalTaxesVarianceEgp,
                  color: statusColor,
                  isGrandTotal: true,
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: kpi1),
                      const SizedBox(width: 12),
                      Expanded(child: kpi2),
                      const SizedBox(width: 12),
                      Expanded(child: kpi3),
                      const SizedBox(width: 12),
                      Expanded(child: kpi4),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: kpi1),
                          const SizedBox(width: 12),
                          Expanded(child: kpi2),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: kpi3),
                          const SizedBox(width: 12),
                          Expanded(child: kpi4),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 18),

            // ── LINE BY LINE COMPARISON TABLE ──────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal.withOpacity(0.06)),
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  fontSize: 12,
                ),
                columns: [
                  DataColumn(label: Text(l.customsTariffItemCol)),
                  DataColumn(label: Text(l.itemDescriptionAndOriginCol)),
                  DataColumn(label: Text(l.quantityAndUnitCol)),
                  DataColumn(label: Text(l.itemPriceCol)),
                  DataColumn(label: Text(l.fobEgpCol)),
                  DataColumn(label: Text(l.cifEgpCol)),
                  DataColumn(label: Text(l.customsDutyCol)),
                  DataColumn(label: Text(l.vatCol)),
                  DataColumn(label: Text(l.totalTaxesAndDutiesCol)),
                  DataColumn(label: Text(l.varianceCol)),
                ],

                rows: res.comparisonLines.map((line) {
                  final lineDiff = line.totalTaxesVarianceEgp;
                  final diffColor = lineDiff > 0
                      ? AppTheme.crimson
                      : (lineDiff < 0 ? AppTheme.emerald : Colors.grey);

                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            line.hsCode,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cobalt,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 170,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                line.itemName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : Colors.black87),
                              ),
                              if (line.countryOfOrigin != null && line.countryOfOrigin!.isNotEmpty)
                                Text(
                                  '${l.originPrefix} ${line.countryOfOrigin}',
                                  style: TextStyle(fontSize: 10, color: isDark ? AppTheme.cobalt : Colors.blue.shade900),
                                ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${line.preliminaryQty.toStringAsFixed(0)} ➔ ${line.finalQty.toStringAsFixed(0)}',
                              style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : Colors.black87),
                            ),
                            if (line.qtyVariance != 0)
                              Text(
                                '${line.qtyVariance > 0 ? "+" : ""}${line.qtyVariance.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: line.qtyVariance > 0 ? AppTheme.crimson : AppTheme.emerald,
                                ),
                              ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          '${line.preliminaryUnitPrice.toStringAsFixed(2)} ➔ ${line.finalUnitPrice.toStringAsFixed(2)}',
                          style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.black87),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${line.finalFobEgp.toStringAsFixed(2)} EGP',
                          style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : Colors.black87),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${line.finalCifEgp.toStringAsFixed(2)} EGP',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : Colors.black87),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${line.dutyRatePct}% (${line.finalDutyEgp.toStringAsFixed(2)})',
                          style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.black87),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${line.vatRatePct}% (${line.finalVatEgp.toStringAsFixed(2)})',
                          style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.black87),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${line.finalTotalTaxesEgp.toStringAsFixed(2)} EGP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: diffColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${lineDiff > 0 ? "+" : ""}${lineDiff.toStringAsFixed(2)} EGP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: diffColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // ── BOTTOM ACTION BAR (SAVE NEW FEES) ──────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.applyRecalculatedDutiesTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                        ),
                        Text(
                          '${res.finalTotalTaxesEgp.toStringAsFixed(2)} EGP',
                          style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onApplyNewFees,
                    icon: const Icon(Icons.save_alt, color: Colors.white, size: 18),
                    label: Text(
                      l.applyAndLinkFinancialEstimate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required BuildContext context,
    required String title,
    required double preliminaryVal,
    required double finalVal,
    required double varianceVal,
    required Color color,
    bool isGrandTotal = false,
  }) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diffSign = varianceVal > 0 ? '+' : '';
    final diffColor = varianceVal > 0
        ? AppTheme.crimson
        : (varianceVal < 0 ? AppTheme.emerald : Colors.grey.shade700);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGrandTotal ? color : (isDark ? AppTheme.darkBorder : color.withOpacity(0.2)),
          width: isGrandTotal ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.preliminaryPoLabel,
                      style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${preliminaryVal.toStringAsFixed(2)} EGP',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                          decoration: varianceVal != 0 ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      l.recalculatedLabel,
                      style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        '${finalVal.toStringAsFixed(2)} EGP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: diffColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${l.varianceLabel} ',
                  style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                ),
                Text(
                  '$diffSign${varianceVal.toStringAsFixed(2)} EGP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: diffColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
