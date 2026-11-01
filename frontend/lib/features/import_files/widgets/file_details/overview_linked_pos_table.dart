// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../../purchase_orders/models/purchase_order_model.dart';
import '../../../purchase_orders/utils/po_packing_matcher.dart';

/// 🛒 Linked Purchase Orders Table for Overview Tab
class OverviewLinkedPosTable extends StatelessWidget {
  final List<PurchaseOrderModel> linkedPOs;
  final bool isDark;

  const OverviewLinkedPosTable({
    super.key,
    required this.linkedPOs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🛒 ${l.linkedPurchaseOrdersTitle}:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
        ),
        const SizedBox(height: 10),
        linkedPOs.isEmpty
            ? Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite, borderRadius: BorderRadius.circular(8)),
                child: Text(l.noLinkedPosForFile, style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : null)),
              )
            : Table(
                border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                columnWidths: const {
                  0: FlexColumnWidth(1.4),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.8),
                  3: FlexColumnWidth(1.6),
                  4: FlexColumnWidth(1.4),
                  5: FlexColumnWidth(1.0),
                  6: FlexColumnWidth(1.5),
                  7: FlexColumnWidth(1.0),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal),
                    children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.purchaseOrder, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.poInvoiceLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.foreignSupplier, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.paymentTermsLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.totalCostMetric, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.packingListItemsCol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.weightCbmCol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(l.status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                  ...linkedPOs.map((po) {
                    final double poPalletCbm = po.palletPlanItems.isNotEmpty
                        ? po.palletPlanItems.fold<double>(0.0, (s, p) => s + (p.calculatedCbm > 0 ? p.calculatedCbm : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount))
                        : (po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0
                            ? (po.palletLengthCm * po.palletWidthCm * po.palletHeightCm / 1000000.0) * po.palletCount
                            : 0.0);
                    final double poPalletGross = po.palletPlanItems.isNotEmpty
                        ? po.palletPlanItems.fold<double>(0.0, (s, p) => s + (p.grossWeightPerPalletKg * p.palletCount))
                        : (po.palletCount > 0 && po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);
                    final int poPalletCount = po.palletPlanItems.isNotEmpty
                        ? po.palletPlanItems.fold<int>(0, (s, p) => s + p.palletCount)
                        : po.palletCount;

                    final poPlCbm = poPalletCbm > 0
                        ? poPalletCbm
                        : (po.totalCbm > 0 && po.packingListItems.isEmpty
                            ? po.totalCbm
                            : (po.packingListItems.isNotEmpty
                                ? po.packingListItems.fold(0.0, (s, pl) => s + (pl.totalCbm > 0 ? pl.totalCbm : pl.calculatedCbm))
                                : po.totalCbm));

                    final poPlWeight = poPalletGross > 0
                        ? poPalletGross
                        : (po.totalGrossWeightKg > 0 && po.packingListItems.isEmpty
                            ? po.totalGrossWeightKg
                            : (po.packingListItems.isNotEmpty
                                ? po.packingListItems.fold(0.0, (s, pl) => s + (pl.totalGrossWeightKg > 0 ? pl.totalGrossWeightKg : (pl.grossWeightUnitKg * pl.qtyPkg)))
                                : po.totalGrossWeightKg));

                    final plText = poPalletCount > 0
                        ? '$poPalletCount ${l.palletsShippingPlan}'
                        : '${po.packingListItems.length} ${l.packingItemsCount}';

                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(po.displayName, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt)),
                              if (po.displayName != po.poNumber)
                                LtrText(po.poNumber, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextMuted : Colors.grey)),
                            ],
                          ),
                        ),
                        Padding(padding: const EdgeInsets.all(8), child: Text(po.proformaInvoiceNumber ?? '-', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(po.supplierName ?? '-', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null))),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkElevatedSurface : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.amber.shade200),
                            ),
                            child: Text(
                              po.paymentTerms ?? '-',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.amber.shade200 : Colors.brown.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.green.shade300 : Colors.green),
                          ),
                        ),
                        Padding(padding: const EdgeInsets.all(8), child: Text(plText, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : null))),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '${poPlCbm.toStringAsFixed(3)} m³ / ${PoPackingMatcher.formatWeight(poPlWeight)} kg',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            po.statusLabel(context.l10n),
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
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
