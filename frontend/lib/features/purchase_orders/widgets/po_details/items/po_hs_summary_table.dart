import 'package:flutter/material.dart';
import '../../../../../core/helpers/table_copy_helper.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../models/purchase_order_model.dart';
import '../../po_table_cells.dart';
import '../po_resolved_metrics.dart';

class PoHsSummaryTable extends StatelessWidget {
  final PurchaseOrderModel po;
  final POResolvedMetrics metrics;
  final bool isDark;

  const PoHsSummaryTable({
    super.key,
    required this.po,
    required this.metrics,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.poPOLineItemsSummaryByHS,
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
            0: FlexColumnWidth(1.6),
            1: FlexColumnWidth(1.0),
            2: FlexColumnWidth(0.9),
            3: FlexColumnWidth(1.1),
            4: FlexColumnWidth(1.1),
            5: FlexColumnWidth(1.1),
            6: FlexColumnWidth(1.3),
            7: FlexColumnWidth(1.4),
            8: FixedColumnWidth(40),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
              ),
              children: [
                PoHeaderCell(l.hsCode, fontSize: 11),
                PoHeaderCell(l.financialSettlementColQty, fontSize: 11),
                PoHeaderCell(l.poQtyPKG, fontSize: 11),
                PoHeaderCell(l.poNetWtKg, fontSize: 11),
                PoHeaderCell(l.poGrossWtKg, fontSize: 11),
                PoHeaderCell(l.freightBookingCbmVolumeLabel, fontSize: 11),
                PoHeaderCell(l.smartExtractorFieldTotalAmount, fontSize: 11),
                PoHeaderCell(l.poDutyVAT, fontSize: 11),
                const Padding(
                  padding: EdgeInsets.all(4),
                  child: Center(
                    child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt),
                  ),
                ),
              ],
            ),
            ...metrics.poHsSummaryMap.values.map((summary) {
              final summaryHs = '${summary['hs_code']}';
              final isMismatched = metrics.mismatchedHsCodes.contains(summaryHs);
              final double net = summary['total_net'] as double;
              final double gross = summary['total_gross'] as double;
              final double cbm = summary['total_cbm'] as double;
              final double price = summary['total_price'] as double;
              final int pkg = summary['qty_pkg'] as int;

              return TableRow(
                decoration: isMismatched ? poMismatchRowDecoration(isDark) : null,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
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
                      '${summary['qty']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '$pkg',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: metrics.isPalletized
                            ? AppTheme.textMuted
                            : (isDark ? AppTheme.darkTextPrimary : null),
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
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${po.currencyCode ?? "USD"} ${price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emerald,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${summary['duty_rate']}% / ${summary['vat_rate']}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textStrong,
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
                          [
                            summaryHs,
                            summary['qty'],
                            pkg,
                            net,
                            gross,
                            cbm,
                            price,
                            '${summary['duty_rate']}%',
                            '${summary['vat_rate']}%',
                          ],
                          headers: [
                            'HS Code',
                            'Qty',
                            'Qty PKG',
                            'Net Weight',
                            'Gross Weight',
                            'CBM',
                            'Total Amount',
                            'Duty Rate',
                            'VAT Rate',
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
