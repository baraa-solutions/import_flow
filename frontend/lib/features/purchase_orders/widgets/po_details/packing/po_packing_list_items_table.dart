import 'package:flutter/material.dart';

import '../../../../../core/helpers/table_copy_helper.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/ltr_text.dart';
import '../../../models/purchase_order_model.dart';
import '../../po_table_cells.dart';
import '../po_resolved_metrics.dart';

class PoPackingListItemsTable extends StatelessWidget {
  final List<PackingListItemModel> packingListItems;
  final POResolvedMetrics metrics;

  const PoPackingListItemsTable({
    super.key,
    required this.packingListItems,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.poPackingListTabCount(packingListItems.length),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 6),
        if (packingListItems.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.noPackingEntriesYetDesc,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
              ),
            ),
          )
        else
          Table(
            border: TableBorder.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
            ),
            columnWidths: const {
              0: FlexColumnWidth(1.6),
              1: FlexColumnWidth(1.1),
              2: FlexColumnWidth(1.6),
              3: FlexColumnWidth(0.9),
              4: FlexColumnWidth(0.9),
              5: FlexColumnWidth(0.9),
              6: FlexColumnWidth(1.3),
              7: FlexColumnWidth(1.0),
              8: FlexColumnWidth(1.0),
              9: FlexColumnWidth(1.0),
              10: FixedColumnWidth(44),
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
                      l.itemCode,
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
                      l.mainDescription,
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
                      l.packageTypeCol,
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
                      l.dimensionsCmCol,
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
                      l.netWeightCol,
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
                      l.grossWeightCol,
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
                      l.cbmVolumeMetric,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Center(
                      child: Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                      ),
                    ),
                  ),
                ],
              ),
              ...packingListItems.map((p) {
                final isMismatched =
                    metrics.reconciliation.items.any((r) => r.hsCode == p.hsCode && !r.isMatched);
                final netWt = (p.netWeightUnitKg > 0 && p.qtyPkg > 0)
                    ? (p.qtyPkg * p.netWeightUnitKg)
                    : p.totalNetWeightKg;
                final grossWt = (p.grossWeightUnitKg > 0 && p.qtyPkg > 0)
                    ? (p.qtyPkg * p.grossWeightUnitKg)
                    : p.totalGrossWeightKg;
                final cbm = p.calculatedCbm > 0 ? p.calculatedCbm : p.totalCbm;

                return TableRow(
                  decoration: isMismatched ? poMismatchRowDecoration(isDark) : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: isMismatched
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.crimsonLight,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.crimson, width: 1.1),
                              ),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 2,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 11, color: AppTheme.crimson),
                                  Text(
                                    p.hsCode.isNotEmpty ? p.hsCode : 'None',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.redAccent : AppTheme.crimson,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : LtrText(
                              p.hsCode,
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
                        p.itemCode,
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        p.mainDescription ?? p.description ?? '-',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${p.qtyPcs}',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${p.qtyPkg}',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        p.packageType,
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        p.lengthCm > 0 ? '${p.lengthCm}x${p.widthCm}x${p.heightCm}' : 'N/A',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        POResolvedMetrics.formatWeight(netWt),
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        POResolvedMetrics.formatWeight(grossWt),
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
                          icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 16),
                          tooltip: l.poCopyRowForExcelTSV,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => TableCopyHelper.copyRow(
                            context,
                            [
                              p.hsCode,
                              p.itemCode,
                              p.mainDescription ?? p.description ?? '-',
                              p.qtyPcs,
                              p.qtyPkg,
                              p.packageType,
                              p.lengthCm > 0 ? '${p.lengthCm}x${p.widthCm}x${p.heightCm}' : 'N/A',
                              netWt,
                              grossWt,
                              cbm,
                            ],
                            headers: [
                              'HS Code',
                              'Item Code',
                              'Description',
                              'Qty (Pcs)',
                              'Qty (Pkg)',
                              'Package Type',
                              'Dimensions (cm)',
                              'Net Weight (kg)',
                              'Gross Weight (kg)',
                              'CBM (m³)',
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
