import 'package:flutter/material.dart';

import '../../../../../core/helpers/table_copy_helper.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../po_table_cells.dart';
import '../po_resolved_metrics.dart';

class PoPackingSummaryReports extends StatelessWidget {
  final POResolvedMetrics metrics;

  const PoPackingSummaryReports({
    super.key,
    required this.metrics,
  });

  Widget _buildPackageTypeSummaryTable({
    required BuildContext context,
    required Map<String, Map<String, dynamic>> packageTypeSummaryMap,
    required bool isDark,
    required AppLocalizations l,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.poPackingListSummaryByPackageType,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 6),
        Table(
          border: TableBorder.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
          ),
          columnWidths: const {
            0: FlexColumnWidth(2.2),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(1.2),
            5: FixedColumnWidth(40),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    l.poPackageType,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    l.poRecReportPackages,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    l.poNetWtKg,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    l.poGrossWtKg,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    l.freightBookingCbmVolumeLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(4),
                  child: Center(
                    child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt),
                  ),
                ),
              ],
            ),
            ...packageTypeSummaryMap.values.map((summary) {
              final String pkgType = '${summary['package_type']}';
              final double qty = (summary['qty_pkg'] as num).toDouble();
              final String qtyStr =
                  qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
              final double net = summary['total_net'] as double;
              final double gross = summary['total_gross'] as double;
              final double cbm = summary['total_cbm'] as double;

              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      pkgType,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cobalt,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      qtyStr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${POResolvedMetrics.formatWeight(net)} kg',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${POResolvedMetrics.formatWeight(gross)} kg',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${cbm.toStringAsFixed(3)} m³',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Icons.copy_rounded,
                          color: AppTheme.cobalt,
                          size: 16,
                        ),
                        tooltip: l.poCopyRowForExcelTSV,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => TableCopyHelper.copyRow(
                          context,
                          [pkgType, qtyStr, net, gross, cbm],
                          headers: [
                            'Package Type',
                            'Total Packages',
                            'Net Weight',
                            'Gross Weight',
                            'CBM',
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📊 ${l.summaryByHsCodeReport}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 6),
        Table(
          border: TableBorder.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    l.hsCode,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    l.qtyPcsCol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    l.qtyPkgCol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    l.totalNetWeightCol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    l.totalGrossWeightCol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    l.totalCargoCbmMetric,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                ),
              ],
            ),
            ...metrics.hsSummaryMap.values.map(
              (summary) {
                final summaryHs = '${summary['hs_code']}';
                final isMismatched = metrics.reconciliation.items
                    .any((r) => r.hsCode == summaryHs && !r.isMatched);
                return TableRow(
                  decoration: isMismatched ? poMismatchRowDecoration(isDark) : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: isMismatched
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 12, color: AppTheme.crimson),
                                const SizedBox(width: 3),
                                Text(
                                  summaryHs,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.redAccent : AppTheme.crimson,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              summaryHs,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.cobalt,
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${summary['qty_pcs']}',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${summary['qty_pkg']}',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${(summary['total_net'] as double).toStringAsFixed(1)} kg',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${(summary['total_gross'] as double).toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${(summary['total_cbm'] as double).toStringAsFixed(3)} m³',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        if (metrics.packageTypeSummaryMap.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildPackageTypeSummaryTable(
            context: context,
            packageTypeSummaryMap: metrics.packageTypeSummaryMap,
            isDark: isDark,
            l: l,
          ),
        ],
      ],
    );
  }
}
