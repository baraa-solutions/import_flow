import 'package:flutter/material.dart';
import '../../../../../core/helpers/table_copy_helper.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../models/purchase_order_model.dart';
import '../../po_table_cells.dart';
import '../po_resolved_metrics.dart';

class PoLineItemsBreakdownTable extends StatelessWidget {
  final PurchaseOrderModel po;
  final POResolvedMetrics metrics;
  final bool isDark;

  const PoLineItemsBreakdownTable({
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
          l.poLineItemsBreakdown,
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
            0: FlexColumnWidth(1.0),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(2.0),
            3: FlexColumnWidth(0.9),
            4: FlexColumnWidth(0.8),
            5: FlexColumnWidth(1.2),
            6: FlexColumnWidth(1.0),
            7: FlexColumnWidth(1.1),
            8: FlexColumnWidth(1.0),
            9: FlexColumnWidth(1.0),
            10: FlexColumnWidth(1.1),
            11: FixedColumnWidth(40),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
              ),
              children: [
                PoHeaderCell(l.itemCode),
                PoHeaderCell(l.mainDescription),
                PoHeaderCell(l.descriptionAndHsCode),
                PoHeaderCell(l.qtyUom),
                PoHeaderCell(l.poQtyPKG),
                PoHeaderCell(l.poPackageType),
                PoHeaderCell(l.unitPrice),
                PoHeaderCell(l.lineTotal),
                PoHeaderCell(l.poNetWt),
                PoHeaderCell(l.poGrossWt),
                PoHeaderCell(l.volumeCbmPackingList),
                const Padding(
                  padding: EdgeInsets.all(6),
                  child: Center(
                    child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt),
                  ),
                ),
              ],
            ),
            ...metrics.resolvedPoItems.map((resolved) {
              final item = resolved.item;
              final double itemCbm = resolved.cbm;
              final double itemNet = resolved.netWeightKg;
              final double itemGross = resolved.grossWeightKg;
              final int itemPkg = resolved.qtyPkg;
              final itemHs = resolved.effectiveHsCode != 'UNSPECIFIED'
                  ? resolved.effectiveHsCode
                  : null;
              final isMismatched = itemHs != null &&
                  itemHs.isNotEmpty &&
                  metrics.mismatchedHsCodes.contains(itemHs);

              return TableRow(
                decoration: isMismatched
                    ? BoxDecoration(
                        color: AppTheme.crimsonLight.withValues(alpha: 0.3),
                      )
                    : null,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(item.itemCode ?? '-'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      item.mainDescription?.isNotEmpty == true
                          ? item.mainDescription!
                          : '-',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.descriptionAr,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (item.countryOfOrigin != null &&
                            item.countryOfOrigin!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              l.itemOriginLabel(item.countryOfOrigin!),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textStrong,
                              ),
                            ),
                          ),
                        if (itemHs != null && itemHs.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: isMismatched
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.crimsonLight,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppTheme.crimson,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 4,
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 12,
                                          color: AppTheme.crimson,
                                        ),
                                        Text(
                                          l.hsMismatchWarning(
                                            '${item.dutyRate ?? 0}%',
                                            '${item.vatRate ?? 0}%',
                                          ),
                                          style: const TextStyle(
                                            color: AppTheme.crimson,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Text(
                                    'HS: $itemHs (${l.fieldImportDuty}: ${item.dutyRate ?? 0}% / ${l.fieldVatAmount}: ${item.vatRate ?? 0}%)',
                                    style: const TextStyle(
                                      color: AppTheme.cobalt,
                                      fontSize: 11,
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('${item.quantity} ${item.unitOfMeasure}'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '$itemPkg',
                      style: TextStyle(
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
                      resolved.packageType,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${po.currencyCode ?? "USD"} ${item.unitPrice.toStringAsFixed(2)}',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${po.currencyCode ?? "USD"} ${item.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emerald,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${POResolvedMetrics.formatWeight(itemNet)} kg',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${POResolvedMetrics.formatWeight(itemGross)} kg',
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
                      '${itemCbm.toStringAsFixed(3)} m³',
                      style: const TextStyle(
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
                          [
                            item.itemCode ?? '-',
                            item.mainDescription ?? '-',
                            item.descriptionAr,
                            itemHs ?? '-',
                            item.quantity,
                            item.unitOfMeasure,
                            itemPkg,
                            resolved.packageType,
                            item.unitPrice,
                            item.totalPrice,
                            itemNet,
                            itemGross,
                            itemCbm,
                          ],
                          headers: [
                            'Item Code',
                            'Main Description',
                            'Description',
                            'HS Code',
                            'Quantity',
                            'Unit',
                            'Qty PKG',
                            'Package Type',
                            'Unit Price',
                            'Total Price',
                            'Net Weight (kg)',
                            'Gross Weight (kg)',
                            'Volume CBM',
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
