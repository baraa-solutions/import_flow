import 'package:flutter/material.dart';
import '../../../../../core/helpers/table_copy_helper.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../po_resolved_metrics.dart';

class PoPackageTypeSummaryTable extends StatelessWidget {
  final Map<String, Map<String, dynamic>> packageTypeSummaryMap;
  final bool isDark;

  const PoPackageTypeSummaryTable({
    super.key,
    required this.packageTypeSummaryMap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

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
}
