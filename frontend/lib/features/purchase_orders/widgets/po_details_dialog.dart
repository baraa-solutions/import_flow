import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/container_load_plan_export_service.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/container_load_plan_painter.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../customs_tariff/widgets/hs_code_compliance_insight_card.dart';
import '../models/po_system_message.dart';
import '../models/purchase_order_model.dart';
import '../utils/po_packing_matcher.dart';
import 'po_reconciliation_warning_dialog.dart';
import 'po_table_cells.dart';
import 'po_fulfillment_progress_widget.dart';
import 'create_partial_shipment_dialog.dart';

/// The isolated, comprehensive Purchase Order Details Dialog (Session 4).
///
/// Features:
/// - Tab 1: Commercial PO Line Items & Reconciliation Summary
/// - Tab 2: Review Packing List & Package Type Summary
/// - Tab 3: Interactive 3D Container Load Planner & Simulation
/// - Overflow-free responsive layout & actions toolbar
class PoDetailsDialog extends ConsumerStatefulWidget {
  final PurchaseOrderModel po;
  final VoidCallback? onEdit;
  final VoidCallback? onOpen3dPlanner;

  const PoDetailsDialog({
    super.key,
    required this.po,
    this.onEdit,
    this.onOpen3dPlanner,
  });

  static Future<void> show(
    BuildContext context,
    PurchaseOrderModel po, {
    VoidCallback? onEdit,
    VoidCallback? onOpen3dPlanner,
  }) {
    return showDialog(
      context: context,
      builder: (dialogCtx) => PoDetailsDialog(
        po: po,
        onEdit: onEdit,
        onOpen3dPlanner: onOpen3dPlanner,
      ),
    );
  }

  static String formatWeight(double val) => PoPackingMatcher.formatWeight(val);
  static List<CargoItem> extractCargoItems(PurchaseOrderModel po) => _PoDetailsDialogState._extractCargoItemsFromPo(po);

  @override
  ConsumerState<PoDetailsDialog> createState() => _PoDetailsDialogState();
}

class _PoDetailsDialogState extends ConsumerState<PoDetailsDialog> {
  PurchaseOrderModel get po => widget.po;
  VoidCallback? get onEdit => widget.onEdit;
  VoidCallback? get onOpen3dPlanner => widget.onOpen3dPlanner;

  static String _formatWeight(double val) => PoPackingMatcher.formatWeight(val);

  @override
  Widget build(BuildContext context) {
    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    if (tariffs.isEmpty) {
      ref.read(customsTariffProvider.notifier).fetchTariffs();
    }
    final reconciliation = evaluatePOReconciliation(
      invoiceItems: po.items,
      packingItems: po.packingListItems,
      tariffs: tariffs,
    );
    final Set<String> mismatchedHsCodes = reconciliation.items
        .where((item) => !item.isMatched || item.isMissingInPacking || item.isMissingInInvoice)
        .map((item) => item.hsCode)
        .toSet();

    // Group packing list items by HS Code for the HS Summary Report
    final Map<String, Map<String, dynamic>> hsSummaryMap = {};
    for (final p in po.packingListItems) {
      final hs = p.hsCode.isNotEmpty ? p.hsCode : 'UNSPECIFIED';
      if (!hsSummaryMap.containsKey(hs)) {
        hsSummaryMap[hs] = {
          'hs_code': hs,
          'qty_pcs': 0.0,
          'qty_pkg': 0.0,
          'total_net': 0.0,
          'total_gross': 0.0,
          'total_cbm': 0.0,
        };
      }
      final double itemNet = (p.netWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.netWeightUnitKg) : p.totalNetWeightKg;
      final double itemGross = (p.grossWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.grossWeightUnitKg) : p.totalGrossWeightKg;
      final double itemCbm = p.calculatedCbm > 0 ? p.calculatedCbm : p.totalCbm;
      hsSummaryMap[hs]!['qty_pcs'] += p.qtyPcs;
      hsSummaryMap[hs]!['qty_pkg'] += p.qtyPkg;
      hsSummaryMap[hs]!['total_net'] += itemNet;
      hsSummaryMap[hs]!['total_gross'] += itemGross;
      hsSummaryMap[hs]!['total_cbm'] += itemCbm;
    }

    final bool isPalletized = (po.palletPlanItems.isNotEmpty && po.palletPlanItems.any((p) => p.palletCount > 0)) || po.palletCount > 0;

    final resolvedPoItems = PoPackingMatcher.resolvePoItemMetrics(
      items: po.items,
      packingListItems: po.packingListItems,
      isPalletized: isPalletized,
      tariffs: tariffs,
    );

    // Group PO Line Items by HS Code for PO Items HS Summary Report
    final Map<String, Map<String, dynamic>> poHsSummaryMap = PoPackingMatcher.buildPoHsSummaryMap(resolvedPoItems);

    // Group Packing List Items by Package Type for Summary By Package Type Report
    final Map<String, Map<String, dynamic>> packageTypeSummaryMap = PoPackingMatcher.buildPackingTypeSummaryMap(po.packingListItems);



    // Validation checks
    final List<String> validationErrors = [];
    final List<String> validationWarnings = [];
    for (int i = 0; i < po.packingListItems.length; i++) {
      final item = po.packingListItems[i];
      if (item.grossWeightUnitKg < item.netWeightUnitKg) {
        validationErrors.add(POSystemMessage(code: 'PO_PL_GROSS_BELOW_NET', params: {
          'line_num': i + 1,
          'item_code': item.itemCode,
          'gross_qty': item.grossWeightUnitKg,
          'net_qty': item.netWeightUnitKg,
        }).text(context.l10n));
      }
      if (item.lengthCm <= 0 || item.widthCm <= 0 || item.heightCm <= 0) {
        validationWarnings.add(POSystemMessage(
          code: 'PO_PL_DIMENSIONS_MISSING',
          params: {'line_num': i + 1, 'item_code': item.itemCode},
        ).text(context.l10n));
      }
    }

        final l = context.l10n;
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SelectionArea(
          child: DefaultTabController(
            length: 3,
            child: AlertDialog(
            backgroundColor: isDark ? AppTheme.darkSurface : null,
            title: Row(
              children: [
                const Icon(Icons.inventory_2, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Text(
                  po.displayName != po.poNumber ? '${l.purchaseOrdersTitle}: ${po.displayName} (${po.poNumber})' : '${l.purchaseOrdersTitle}: ${po.displayName}',
                  style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: math.min(1180.0, MediaQuery.of(context).size.width - 32),
              height: math.min(780.0, MediaQuery.of(context).size.height - 48),
              child: Column(
                children: [
                  Container(
                    color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoalSurface,
                    child: TabBar(
                      labelColor: AppTheme.cobalt,
                      unselectedLabelColor: AppTheme.textMuted,
                      indicatorColor: AppTheme.cobalt,
                      tabs: [
                        Tab(icon: const Icon(Icons.receipt_long, size: 18), text: l.poLineItemsTab),
                        Tab(icon: const Icon(Icons.fact_check, size: 18), text: l.reviewPackingListTab),
                        Tab(icon: const Icon(Icons.view_in_ar_rounded, size: 18), text: l.containerLoadPlan3dTitle),
                      ],
                    ),
                  ),
                  if (po.createdBy != null || po.updatedBy != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 12, end: 12, top: 6, bottom: 2),
                      child: Row(
                        children: [
                          if (po.createdBy != null) ...[
                            Text('${l.poAuditCreatedBy}: ', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            LtrText(po.createdBy!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 16),
                          ],
                          if (po.updatedBy != null) ...[
                            Text('${l.poAuditUpdatedBy}: ', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            LtrText(po.updatedBy!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Commercial PO Line Items
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Builder(builder: (context) {
                              final double palletPlanCbm = po.palletPlanItems.isNotEmpty
                                  ? po.palletPlanItems.fold<double>(
                                      0.0,
                                      (sum, p) => sum + (p.calculatedCbm > 0 ? p.calculatedCbm : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount),
                                    )
                                  : (po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0
                                      ? (po.palletLengthCm * po.palletWidthCm * po.palletHeightCm / 1000000.0) * po.palletCount
                                      : (po.palletCount > 0 && po.totalCbm > 0 ? po.totalCbm : 0.0));
                              final double palletPlanGrossWeight = po.palletPlanItems.isNotEmpty
                                  ? po.palletPlanItems.fold<double>(
                                      0.0,
                                      (sum, p) => sum + (p.grossWeightPerPalletKg * p.palletCount),
                                    )
                                  : (po.palletCount > 0 && po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);
                              final int totalPalletCount = po.palletPlanItems.isNotEmpty
                                  ? po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount)
                                  : po.palletCount;

                              final double effectivePackingListCbm = palletPlanCbm > 0
                                  ? palletPlanCbm
                                  : (po.totalCbm > 0
                                      ? po.totalCbm
                                      : (po.packingListItems.isNotEmpty
                                          ? po.packingListItems.fold(0.0, (sum, pl) => sum + (pl.calculatedCbm > 0 ? pl.calculatedCbm : pl.totalCbm))
                                          : 0.0));
                              final double effectivePackingListGrossWeight = palletPlanGrossWeight > 0
                                  ? palletPlanGrossWeight
                                  : (po.totalGrossWeightKg > 0
                                      ? po.totalGrossWeightKg
                                      : (po.packingListItems.isNotEmpty
                                          ? po.packingListItems.fold(0.0, (sum, pl) => sum + ((pl.grossWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.grossWeightUnitKg * pl.qtyPkg) : pl.totalGrossWeightKg))
                                          : 0.0));
                              final double effectivePackingListNetWeight = po.totalNetWeightKg > 0
                                  ? po.totalNetWeightKg
                                  : (po.packingListItems.isNotEmpty
                                      ? po.packingListItems.fold(0.0, (sum, pl) => sum + ((pl.netWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.netWeightUnitKg * pl.qtyPkg) : pl.totalNetWeightKg))
                                      : 0.0);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: POFulfillmentProgressWidget.fromPO(
                                      po: po,
                                      isCompact: true,
                                      onAllocatePressed: () => showCreatePartialShipmentDialog(context, po: po),
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 20,
                                    runSpacing: 10,
                                    children: [
                                      _buildDetailItem(l.projectsAndCostCenters, po.projectName ?? '-', isDark: isDark),
                                      _buildDetailItem(l.importingCompany, po.companyName ?? '-', isDark: isDark),
                                      _buildDetailItem(l.foreignSupplier, po.supplierName ?? '-', isDark: isDark),
                                      _buildDetailItem(l.countryOfOriginCol, po.countryOfOrigin ?? '-', isDark: isDark),
                                      _buildDetailItem(l.incotermsRules, po.incotermCode ?? '-', isDark: isDark),
                                      _buildDetailItem(l.currency, '${po.currencyCode ?? "USD"} (${l.exchangeRateLabel}: ${po.exchangeRate})', isDark: isDark),
                                      _buildDetailItem(
                                        context.l10n.poInvoiceDate,
                                        po.orderDate != null
                                            ? "${po.orderDate!.year}-${po.orderDate!.month.toString().padLeft(2, '0')}-${po.orderDate!.day.toString().padLeft(2, '0')}"
                                            : '-',
                                        isDark: isDark,
                                      ),
                                      _buildDetailItem(
                                        context.l10n.poQtyUnit,
                                        po.items.isNotEmpty ? po.items.first.unitOfMeasure : 'PCS',
                                        isDark: isDark,
                                      ),
                                      _buildDetailItem(l.paymentTermsLabel, po.paymentTerms ?? '-', isDark: isDark),
                                      _buildDetailItem(l.totalFobMetric, '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}', isDark: isDark),
                                      _buildDetailItem(
                                        l.totalCargoCbmMetric,
                                        '${effectivePackingListCbm.toStringAsFixed(3)} m³${totalPalletCount > 0 ? " ($totalPalletCount)" : ""}',
                                        isDark: isDark,
                                      ),
                                      _buildDetailItem(
                                        l.grossWeightMetric,
                                        '${_formatWeight(effectivePackingListGrossWeight)} kg',
                                        isDark: isDark,
                                      ),
                                      _buildDetailItem(
                                        l.netWeightMetric,
                                        '${_formatWeight(effectivePackingListNetWeight)} kg',
                                        isDark: isDark,
                                      ),
                                      _buildDetailItem(
                                        context.l10n.poTotalQtyPKG,
                                        PoPackingMatcher.formatPackagingSummary(
                                          packingListItems: po.packingListItems,
                                          totalPalletCount: totalPalletCount,
                                          isArabic: isArabic,
                                        ),
                                        isDark: isDark,
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 16),
                                Text(l.poLineItemsBreakdown, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                                const SizedBox(height: 6),
                                SelectionArea(
                                  child: Table(
                                    border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
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
                                        decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                        children: [
                                          PoHeaderCell(l.itemCode),
                                          PoHeaderCell(l.mainDescription),
                                          PoHeaderCell(l.descriptionAndHsCode),
                                          PoHeaderCell(l.qtyUom),
                                          PoHeaderCell(context.l10n.poQtyPKG),
                                          PoHeaderCell(context.l10n.poPackageType),
                                          PoHeaderCell(l.unitPrice),
                                          PoHeaderCell(l.lineTotal),
                                          PoHeaderCell(context.l10n.poNetWt),
                                          PoHeaderCell(context.l10n.poGrossWt),
                                          PoHeaderCell(l.volumeCbmPackingList),
                                          const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: Center(
                                              child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt),
                                            ),
                                          ),
                                        ],
                                      ),
                                      ...resolvedPoItems.map(
                                        (resolved) {
                                          final item = resolved.item;
                                          final double itemCbm = resolved.cbm;
                                          final double itemNet = resolved.netWeightKg;
                                          final double itemGross = resolved.grossWeightKg;
                                          final int itemPkg = resolved.qtyPkg;
                                          final itemHs = resolved.effectiveHsCode != 'UNSPECIFIED' ? resolved.effectiveHsCode : null;
                                          final isMismatched = itemHs != null && itemHs.isNotEmpty && mismatchedHsCodes.contains(itemHs);

                                          return TableRow(
                                            decoration: isMismatched ? BoxDecoration(color: AppTheme.crimsonLight.withValues(alpha: 0.3)) : null,
                                            children: [
                                              Padding(padding: const EdgeInsets.all(6), child: Text(item.itemCode ?? '-')),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Text(
                                                  item.mainDescription?.isNotEmpty == true ? item.mainDescription! : '-',
                                                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(item.descriptionAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                    if (item.countryOfOrigin != null && item.countryOfOrigin!.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 2),
                                                        child: Text(l.itemOriginLabel(item.countryOfOrigin!), style: const TextStyle(fontSize: 11, color: AppTheme.textStrong)),
                                                      ),
                                                    if (itemHs != null && itemHs.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4),
                                                        child: isMismatched
                                                            ? Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: AppTheme.crimsonLight,
                                                                  borderRadius: BorderRadius.circular(4),
                                                                  border: Border.all(color: AppTheme.crimson, width: 1.2),
                                                                ),
                                                                child: Wrap(
                                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                                  spacing: 4,
                                                                  children: [
                                                                    const Icon(Icons.warning_amber_rounded, size: 12, color: AppTheme.crimson),
                                                                    Text(
                                                                      l.hsMismatchWarning('${item.dutyRate ?? 0}%', '${item.vatRate ?? 0}%'),
                                                                      style: const TextStyle(color: AppTheme.crimson, fontSize: 11, fontWeight: FontWeight.bold),
                                                                    ),
                                                                  ],
                                                                ),
                                                              )
                                                            : Text(
                                                                'HS: $itemHs (${l.fieldImportDuty}: ${item.dutyRate ?? 0}% / ${l.fieldVatAmount}: ${item.vatRate ?? 0}%)',
                                                                style: const TextStyle(color: AppTheme.cobalt, fontSize: 11),
                                                              ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${item.quantity} ${item.unitOfMeasure}')),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Text(
                                                  '$itemPkg',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isPalletized ? AppTheme.textMuted : (isDark ? AppTheme.darkTextPrimary : null),
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
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${po.currencyCode ?? "USD"} ${item.unitPrice.toStringAsFixed(2)}')),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Text(
                                                  '${po.currencyCode ?? "USD"} ${item.totalPrice.toStringAsFixed(2)}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                                ),
                                              ),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${_formatWeight(itemNet)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${_formatWeight(itemGross)} kg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Text(
                                                  '${itemCbm.toStringAsFixed(3)} m³',
                                                  style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                                child: Center(
                                                  child: IconButton(
                                                    icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 16),
                                                    tooltip: context.l10n.poCopyRowForExcelTSV,
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
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),
                                Text(
                                  context.l10n.poPOLineItemsSummaryByHS,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                ),
                                const SizedBox(height: 6),
                                SelectionArea(
                                  child: Table(
                                    border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
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
                                        decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                        children: [
                                          PoHeaderCell(l.hsCode, fontSize: 11),
                                          PoHeaderCell(context.l10n.financialSettlementColQty, fontSize: 11),
                                          PoHeaderCell(context.l10n.poQtyPKG, fontSize: 11),
                                          PoHeaderCell(context.l10n.poNetWtKg, fontSize: 11),
                                          PoHeaderCell(context.l10n.poGrossWtKg, fontSize: 11),
                                          PoHeaderCell(context.l10n.freightBookingCbmVolumeLabel, fontSize: 11),
                                          PoHeaderCell(context.l10n.smartExtractorFieldTotalAmount, fontSize: 11),
                                          PoHeaderCell(context.l10n.poDutyVAT, fontSize: 11),
                                          const Padding(padding: EdgeInsets.all(4), child: Center(child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt))),
                                        ],
                                      ),
                                      ...poHsSummaryMap.values.map((summary) {
                                        final summaryHs = '${summary['hs_code']}';
                                        final isMismatched = mismatchedHsCodes.contains(summaryHs);
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
                                              child: Text(summaryHs, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                            ),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${summary['qty']}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('$pkg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPalletized ? AppTheme.textMuted : (isDark ? AppTheme.darkTextPrimary : null)))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${_formatWeight(net)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${_formatWeight(gross)} kg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${cbm.toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11, color: AppTheme.orange, fontWeight: FontWeight.bold))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${po.currencyCode ?? "USD"} ${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${summary['duty_rate']}% / ${summary['vat_rate']}%', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong))),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                              child: Center(
                                                child: IconButton(
                                                  icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 16),
                                                  tooltip: context.l10n.poCopyRowForExcelTSV,
                                                  visualDensity: VisualDensity.compact,
                                                  onPressed: () => TableCopyHelper.copyRow(
                                                    context,
                                                    [summaryHs, summary['qty'], pkg, net, gross, cbm, price, '${summary['duty_rate']}%', '${summary['vat_rate']}%'],
                                                    headers: ['HS Code', 'Qty', 'Qty PKG', 'Net Weight', 'Gross Weight', 'CBM', 'Total Amount', 'Duty Rate', 'VAT Rate'],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  context.l10n.poRegulatoryConditionsTradeAgreementsByHS,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...poHsSummaryMap.values.map((summary) {
                                  final summaryHs = '${summary['hs_code']}';
                                  final tariff = tariffs.where((t) =>
                                      t.hsCode == summaryHs ||
                                      t.hsCode.replaceAll('.', '') == summaryHs.replaceAll('.', '')).firstOrNull;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: HsCodeComplianceInsightCard(
                                      hsCode: summaryHs,
                                      tariff: tariff,
                                      countryOfOrigin: po.countryOfOrigin,
                                      isDark: isDark,
                                      isArabic: isArabic,
                                    ),
                                  );
                                }),
                                if (packageTypeSummaryMap.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  _buildPackageTypeSummaryTable(
                                    context: context,
                                    packageTypeSummaryMap: packageTypeSummaryMap,
                                    isDark: isDark,
                                    isArabic: isArabic,
                                  ),
                                ],
                              ],
                            );
                          }),
                        ),


                      // Tab 2: BP-003 Review Packing List
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reconciliation & Discrepancy Status Banner
                            if (po.packingListItems.isNotEmpty) ...[
                              if (reconciliation.hasDiscrepancy)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.orangeLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isDark ? AppTheme.wcagOrange : AppTheme.orange),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            context.l10n.poInvoicePackingReconciliationDiscrepanciesFound,
                                            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.orange : AppTheme.wcagOrange),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ...(isArabic ? reconciliation.discrepancySummaryList : (reconciliation.discrepancySummaryListEn.isNotEmpty ? reconciliation.discrepancySummaryListEn : reconciliation.discrepancySummaryList)).map(
                                        (d) => Padding(
                                          padding: const EdgeInsetsDirectional.only(top: 2, start: 24),
                                          child: Text('• $d', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.orangeLight : AppTheme.wcagOrange)),
                                        ),
                                      ),
                                      if (po.notes != null && po.notes!.contains('[مبررات اختلاف الفاتورة والباكينج]')) ...[
                                        const Divider(height: 14),
                                        Text(
                                          '${context.l10n.poApprovedJustification} ${po.notes!.split('[مبررات اختلاف الفاتورة والباكينج]:').last.trim()}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emeraldLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isDark ? AppTheme.wcagEmerald : AppTheme.emeraldBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_outlined, color: AppTheme.emerald, size: 18),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          context.l10n.poPerfectMatchAllProformaInvoiceLine,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],

                            // Validation Status Banner
                            if (validationErrors.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: AppTheme.crimsonLight, borderRadius: BorderRadius.circular(6), border: Border.all(color: isDark ? AppTheme.crimson : AppTheme.crimsonBorder)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: AppTheme.crimson, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          context.l10n.poPackingListValidationErrors,
                                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.redAccent : AppTheme.crimson),
                                        ),
                                      ],
                                    ),
                                    ...validationErrors.map((e) => Padding(padding: const EdgeInsetsDirectional.only(top: 4, start: 24), child: Text('• $e', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.crimsonBorder : AppTheme.crimson)))),
                                  ],
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: AppTheme.emeraldLight, borderRadius: BorderRadius.circular(6), border: Border.all(color: isDark ? AppTheme.wcagEmerald : AppTheme.emeraldBorder)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      context.l10n.poPackingListValidationPassedAllWeights,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                    ),
                                  ],
                                ),
                              ),

                            if (validationWarnings.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: AppTheme.orangeLight, borderRadius: BorderRadius.circular(6), border: Border.all(color: isDark ? AppTheme.wcagOrange : AppTheme.orange)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: validationWarnings.map((w) => Text('⚠️ $w', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.orange : AppTheme.wcagOrange))).toList(),
                                ),
                              ),

                            if (po.packingListItems.isNotEmpty && po.palletPlanItems.isEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.orange.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.view_in_ar_rounded, color: AppTheme.orange, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        context.l10n.po3DContainerLoadSimulationAvailableFor(po.packingListItems.length, po.packingListItems.fold<int>(0, (s, p) => s + (p.qtyPkg > 0 ? p.qtyPkg.toInt() : 1))),
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                      ),
                                    ),
                                    AppButton(
                                      label: l.containerLoadPlan3dTitle,
                                      icon: Icons.view_in_ar_rounded,
                                      variant: AppButtonVariant.warning,
                                      size: AppButtonSize.small,
                                      onPressed: () => onOpen3dPlanner?.call(),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (po.palletPlanItems.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoalSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite, width: 1.2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.pallet, color: AppTheme.cobalt, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          l.masterPalletPlanTitle,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cobalt.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            '🔢 ${l.totalPalletsMetric}: ${l.palletCountWithUnit(po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount))}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.orange.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            '📐 ${l.palletCbmWithUnit(po.palletPlanItems.fold<double>(0.0, (sum, p) => sum + (p.calculatedCbm > 0 ? p.calculatedCbm : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount)).toStringAsFixed(3))}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        AppButton(
                                          label: l.simulateAndLoad3d(po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount)),
                                          icon: Icons.view_in_ar_rounded,
                                          variant: AppButtonVariant.warning,
                                          size: AppButtonSize.small,
                                          onPressed: () => onOpen3dPlanner?.call(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Table(
                                      border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                                      children: [
                                        TableRow(
                                          decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                          children: [
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletTypeCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletCountCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletDimensionsCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletWeightCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletTotalWeightCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletVolumeCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.palletStackingInstructionsCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                          ],
                                        ),
                                        ...po.palletPlanItems.map((pal) {
                                          final palCbm = pal.calculatedCbm > 0 ? pal.calculatedCbm : (pal.lengthCm * pal.widthCm * pal.heightCm / 1000000.0) * pal.palletCount;
                                          final palTotalWt = pal.grossWeightPerPalletKg * pal.palletCount;
                                          return TableRow(
                                            children: [
                                              Padding(padding: const EdgeInsets.all(6), child: Text(pal.palletType, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${pal.palletCount}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${pal.lengthCm.toStringAsFixed(0)} × ${pal.widthCm.toStringAsFixed(0)} × ${pal.heightCm.toStringAsFixed(0)} cm', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${pal.grossWeightPerPalletKg.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${palTotalWt.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${palCbm.toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange))),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Text(
                                                  pal.isStackable ? l.stackableOption : l.nonStackableOption,
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pal.isStackable ? (isDark ? AppTheme.emerald : AppTheme.wcagEmerald) : AppTheme.wcagOrange),
                                                ),
                                              ),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            Text(l.poPackingListTabCount(po.packingListItems.length), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                            const SizedBox(height: 6),

                            if (po.packingListItems.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(l.noPackingEntriesYetDesc, style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted)),
                              )
                            else
                              SelectionArea(
                                child: Table(
                                  border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
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
                                      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                      children: [
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.hsCode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.itemCode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.mainDescription, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.qtyPcsCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.qtyPkgCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.packageTypeCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.dimensionsCmCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.netWeightCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.grossWeightCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(padding: const EdgeInsets.all(6), child: Text(l.cbmVolumeMetric, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                        Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Center(
                                            child: Icon(Icons.copy_rounded, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                          ),
                                        ),
                                      ],
                                    ),
                                    ...po.packingListItems.map(
                                      (p) {
                                        final isMismatched = reconciliation.items.any((r) => r.hsCode == p.hsCode && !r.isMatched);
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
                                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.redAccent : AppTheme.crimson),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  : LtrText(p.hsCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                            ),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(p.itemCode, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(p.mainDescription ?? p.description ?? '-', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${p.qtyPcs}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${p.qtyPkg}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(p.packageType, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(p.lengthCm > 0 ? '${p.lengthCm}x${p.widthCm}x${p.heightCm}' : 'N/A', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(_formatWeight((p.netWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.netWeightUnitKg) : p.totalNetWeightKg), style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(_formatWeight((p.grossWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.grossWeightUnitKg) : p.totalGrossWeightKg), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text('${(p.calculatedCbm > 0 ? p.calculatedCbm : p.totalCbm).toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11, color: AppTheme.orange, fontWeight: FontWeight.bold))),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                              child: Center(
                                                child: IconButton(
                                                  icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 16),
                                                  tooltip: context.l10n.poCopyRowForExcelTSV,
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
                                                      ((p.netWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.netWeightUnitKg) : p.totalNetWeightKg),
                                                      ((p.grossWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.grossWeightUnitKg) : p.totalGrossWeightKg),
                                                      (p.calculatedCbm > 0 ? p.calculatedCbm : p.totalCbm),
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
                                      },
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 20),
                            Text('📊 ${l.summaryByHsCodeReport}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                            const SizedBox(height: 6),
                            SelectionArea(
                              child: Table(
                                border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                    children: [
                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.hsCode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.qtyPcsCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.qtyPkgCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.totalNetWeightCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.totalGrossWeightCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.totalCargoCbmMetric, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                    ],
                                  ),
                                  ...hsSummaryMap.values.map(
                                    (summary) {
                                      final summaryHs = '${summary['hs_code']}';
                                      final isMismatched = reconciliation.items.any((r) => r.hsCode == summaryHs && !r.isMatched);
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
                                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.redAccent : AppTheme.crimson),
                                                      ),
                                                    ],
                                                  )
                                                : Text(summaryHs, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                          ),
                                          Padding(padding: const EdgeInsets.all(6), child: Text('${summary['qty_pcs']}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text('${summary['qty_pkg']}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text('${(summary['total_net'] as double).toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text('${(summary['total_gross'] as double).toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                          Padding(padding: const EdgeInsets.all(6), child: Text('${(summary['total_cbm'] as double).toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11, color: AppTheme.orange, fontWeight: FontWeight.bold))),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (packageTypeSummaryMap.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _buildPackageTypeSummaryTable(
                                context: context,
                                packageTypeSummaryMap: packageTypeSummaryMap,
                                isDark: isDark,
                                isArabic: isArabic,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Tab 3: 3D Container Load Planner & Simulation
                      _buildPo3dLoadPlannerTab(context, po, isDark, isArabic, l),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsOverflowButtonSpacing: 8,
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
            AppButton(
              label: l.containerLoadPlan3dTitle,
              icon: Icons.view_in_ar_rounded,
              variant: AppButtonVariant.warning,
              onPressed: () => onOpen3dPlanner?.call(),
            ),
            AppButton(
              label: context.l10n.originalDocsExportExcelBtn,
              icon: Icons.table_chart,
              variant: AppButtonVariant.success,
              onPressed: () {
                _exportPoToExcel(context, po, isArabic);
              },
            ),
            AppButton(
              label: context.l10n.exportPdf,
              icon: Icons.picture_as_pdf,
              variant: AppButtonVariant.danger,
              onPressed: () {
                _exportPoToPdf(context, po, isArabic);
              },
            ),
            AppButton(
              label: l.copyAllData,
              icon: Icons.copy_all,
              variant: AppButtonVariant.secondary,
              onPressed: () {
                _copyPoDetailsToClipboard(context, po, isArabic);
              },
            ),
            AppButton(
              label: l.editPurchaseOrder,
              icon: Icons.edit,
              variant: AppButtonVariant.primary,
              onPressed: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
            AppButton(
              label: l.close,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ],
    ),
  ),
);

  }

  void _copyPoDetailsToClipboard(BuildContext context, PurchaseOrderModel po, bool isArabic) {
    final buffer = StringBuffer();
    buffer.writeln(context.l10n.poPurchaseOrderProformaInvoiceDetails);
    buffer.writeln('${context.l10n.poPOReferenceName}: ${po.displayName}');
    if (po.displayName != po.poNumber) {
      buffer.writeln('${context.l10n.poInternalPOCode}: ${po.poNumber}');
    }
    if (po.proformaInvoiceNumber != null && po.proformaInvoiceNumber!.isNotEmpty) {
      buffer.writeln('${context.l10n.poProformaInvoice}: ${po.proformaInvoiceNumber}');
    }
    if (po.projectName != null && po.projectName!.isNotEmpty) {
      buffer.writeln('${context.l10n.poProjectCostCenter}: ${po.projectName}');
    }
    if (po.companyName != null && po.companyName!.isNotEmpty) {
      buffer.writeln('${context.l10n.operationalTsvHeaderImporter}: ${po.companyName}');
    }
    if (po.supplierName != null && po.supplierName!.isNotEmpty) {
      buffer.writeln('${context.l10n.operationalTsvHeaderSupplier}: ${po.supplierName}');
    }
    if (po.countryOfOrigin != null && po.countryOfOrigin!.isNotEmpty) {
      buffer.writeln('${context.l10n.countryOfOriginCol}: ${po.countryOfOrigin}');
    }
    if (po.incotermCode != null && po.incotermCode!.isNotEmpty) {
      buffer.writeln('${context.l10n.poIncoterms}: ${po.incotermCode}');
    }
    buffer.writeln('${context.l10n.currency}: ${po.currencyCode ?? "USD"} (${context.l10n.poFXRate}: ${po.exchangeRate})');
    if (po.paymentTerms != null && po.paymentTerms!.isNotEmpty) {
      buffer.writeln('${context.l10n.poPaymentTerms}: ${po.paymentTerms}');
    }
    buffer.writeln('${context.l10n.smartExtractorFieldTotalAmount}: ${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}');
    buffer.writeln('${context.l10n.poTotalCBM}: ${po.totalCbm.toStringAsFixed(3)} m³');
    buffer.writeln('${context.l10n.poGrossNetWeight}: ${po.totalGrossWeightKg.toStringAsFixed(1)} kg / ${po.totalNetWeightKg.toStringAsFixed(1)} kg');
    buffer.writeln('${context.l10n.smartExtractorFieldPackagesCount}: ${po.totalPackagesCount} ${po.packingListItems.isNotEmpty ? po.packingListItems.first.packageType : "Carton"}');
    buffer.writeln('${context.l10n.drillDownLabelStatus}: ${po.statusLabel(context.l10n)}');
    if (po.notes != null && po.notes!.isNotEmpty) {
      buffer.writeln('${context.l10n.customsClearanceColNotes}: ${po.notes}');
    }
    buffer.writeln();

    buffer.writeln(context.l10n.poPOLineItemsHSCodes);
    buffer.writeln('Item Code\tMain Description\tDescription & HS Code\tQty / UOM\tUnit Price\tLine Total\tVolume CBM');
    for (final item in po.items) {
      buffer.writeln(
        '${item.itemCode ?? "-"}\t${item.mainDescription ?? "-"}\t${item.descriptionAr} (HS: ${item.hsCode ?? "-"})\t${item.quantity} ${item.unitOfMeasure}\t${po.currencyCode ?? "USD"} ${item.unitPrice.toStringAsFixed(2)}\t${po.currencyCode ?? "USD"} ${item.totalPrice.toStringAsFixed(2)}\t${item.totalCbm.toStringAsFixed(3)}',
      );
    }

    if (po.packingListItems.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(context.l10n.poPackingListItems);
      buffer.writeln('HS Code\tItem Code\tDescription\tPackages\tPackage Type\tDimensions (cm)\tNet Weight (kg)\tGross Weight (kg)\tCBM');
      for (final pl in po.packingListItems) {
        final dims = pl.lengthCm > 0 ? '${pl.lengthCm}x${pl.widthCm}x${pl.heightCm}' : '-';
        final netWt = _formatWeight((pl.netWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.qtyPkg * pl.netWeightUnitKg) : pl.totalNetWeightKg);
        final grossWt = _formatWeight((pl.grossWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.qtyPkg * pl.grossWeightUnitKg) : pl.totalGrossWeightKg);
        final cbm = (pl.calculatedCbm > 0 ? pl.calculatedCbm : pl.totalCbm).toStringAsFixed(3);
        buffer.writeln(
          '${pl.hsCode}\t${pl.itemCode}\t${pl.description ?? pl.mainDescription ?? "-"}\t${pl.qtyPkg}\t${pl.packageType}\t$dims\t$netWt\t$grossWt\t$cbm',
        );
      }
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: context.l10n.poPODetailsCopiedToClipboard,
    );
  }

  Future<void> _exportPoToExcel(BuildContext context, PurchaseOrderModel po, bool isArabic) async {
    final bool isPalletized = (po.palletPlanItems.isNotEmpty && po.palletPlanItems.any((p) => p.palletCount > 0)) || po.palletCount > 0;

    final headers = [
      context.l10n.gitColItemCode,
      context.l10n.poRecColDescription,
      context.l10n.requirementsTsvHeaderHsCode,
      context.l10n.financialSettlementColQty,
      context.l10n.unitCol,
      context.l10n.poQtyPKG,
      context.l10n.poPackageType,
      context.l10n.smartExtractorColUnitPrice,
      context.l10n.freightDataTotalLabel,
      context.l10n.poNetWtKg,
      context.l10n.poGrossWtKg,
      context.l10n.poCBM,
    ];

    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    final resolvedPoItems = PoPackingMatcher.resolvePoItemMetrics(
      items: po.items,
      packingListItems: po.packingListItems,
      isPalletized: isPalletized,
      tariffs: tariffs,
    );

    final rows = resolvedPoItems.map((resolved) {
      final item = resolved.item;
      return [
        item.itemCode ?? '-',
        item.mainDescription ?? item.descriptionAr,
        resolved.effectiveHsCode != 'UNSPECIFIED' ? resolved.effectiveHsCode : (item.hsCode ?? '-'),
        '${item.quantity}',
        item.unitOfMeasure,
        '${resolved.qtyPkg}',
        resolved.packageType,
        '${po.currencyCode ?? "USD"} ${item.unitPrice.toStringAsFixed(2)}',
        '${po.currencyCode ?? "USD"} ${item.totalPrice.toStringAsFixed(2)}',
        _formatWeight(resolved.netWeightKg),
        _formatWeight(resolved.grossWeightKg),
        resolved.cbm.toStringAsFixed(3),
      ];
    }).toList();

    // Section 1: PO Line Items Summary By HS Code
    final Map<String, Map<String, dynamic>> poHsSummaryMap = PoPackingMatcher.buildPoHsSummaryMap(resolvedPoItems);

    final poHsHeaders = [
      context.l10n.requirementsTsvHeaderHsCode,
      context.l10n.financialSettlementColQty,
      context.l10n.poQtyPKG,
      context.l10n.poNetWtKg,
      context.l10n.poGrossWtKg,
      context.l10n.freightBookingCbmVolumeLabel,
      context.l10n.smartExtractorFieldTotalAmount,
      context.l10n.poDutyVAT,
    ];

    final poHsRows = poHsSummaryMap.values.map((s) {
      return [
        '${s['hs_code']}',
        '${s['qty']}',
        '${s['qty_pkg']}',
        _formatWeight(s['total_net'] as double),
        _formatWeight(s['total_gross'] as double),
        (s['total_cbm'] as double).toStringAsFixed(3),
        '${po.currencyCode ?? "USD"} ${(s['total_price'] as double).toStringAsFixed(2)}',
        '${s['duty_rate']}% / ${s['vat_rate']}%',
      ];
    }).toList();

    final List<TableExportSection> additionalSections = [
      TableExportSection(
        title: context.l10n.poPOLineItemsSummaryByHS,
        headers: poHsHeaders,
        rows: poHsRows,
      ),
    ];

    // Section 2: Packing List Summary By HS Code (if packing list exists)
    if (po.packingListItems.isNotEmpty) {
      final Map<String, Map<String, dynamic>> hsSummaryMap = {};
      for (final p in po.packingListItems) {
        final hs = p.hsCode.isNotEmpty ? p.hsCode : 'UNSPECIFIED';
        if (!hsSummaryMap.containsKey(hs)) {
          hsSummaryMap[hs] = {
            'hs_code': hs,
            'qty_pcs': 0.0,
            'qty_pkg': 0.0,
            'total_net': 0.0,
            'total_gross': 0.0,
            'total_cbm': 0.0,
          };
        }
        final double plNet = (p.netWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.netWeightUnitKg) : p.totalNetWeightKg;
        final double plGross = (p.grossWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.grossWeightUnitKg) : p.totalGrossWeightKg;
        final double plCbm = p.calculatedCbm > 0 ? p.calculatedCbm : p.totalCbm;
        hsSummaryMap[hs]!['qty_pcs'] += p.qtyPcs;
        hsSummaryMap[hs]!['qty_pkg'] += p.qtyPkg;
        hsSummaryMap[hs]!['total_net'] += plNet;
        hsSummaryMap[hs]!['total_gross'] += plGross;
        hsSummaryMap[hs]!['total_cbm'] += plCbm;
      }

      final plHsHeaders = [
        context.l10n.requirementsTsvHeaderHsCode,
        context.l10n.poQtyPcs,
        context.l10n.poQtyPKG,
        context.l10n.poNetWtKg,
        context.l10n.poGrossWtKg,
        context.l10n.freightBookingCbmVolumeLabel,
      ];

      final plHsRows = hsSummaryMap.values.map((s) {
        return [
          '${s['hs_code']}',
          '${s['qty_pcs']}',
          '${s['qty_pkg']}',
          _formatWeight(s['total_net'] as double),
          _formatWeight(s['total_gross'] as double),
          (s['total_cbm'] as double).toStringAsFixed(3),
        ];
      }).toList();

      additionalSections.add(
        TableExportSection(
          title: context.l10n.poPackingListSummaryByHSCode,
          headers: plHsHeaders,
          rows: plHsRows,
        ),
      );
    }

    // Section 3: Packing List Summary By Package Type (if packing list exists)
    final packageTypeSummaryMap = PoPackingMatcher.buildPackingTypeSummaryMap(po.packingListItems);
    if (packageTypeSummaryMap.isNotEmpty) {
      final pkgHeaders = [
        context.l10n.poPackageType,
        context.l10n.poRecReportPackages,
        context.l10n.poNetWtKg,
        context.l10n.poGrossWtKg,
        context.l10n.freightBookingCbmVolumeLabel,
      ];

      final pkgRows = packageTypeSummaryMap.values.map((s) {
        final double qty = (s['qty_pkg'] as num).toDouble();
        final String qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
        return [
          '${s['package_type']}',
          qtyStr,
          _formatWeight(s['total_net'] as double),
          _formatWeight(s['total_gross'] as double),
          (s['total_cbm'] as double).toStringAsFixed(3),
        ];
      }).toList();

      additionalSections.add(
        TableExportSection(
          title: context.l10n.poPackingListSummaryByPackageType,
          headers: pkgHeaders,
          rows: pkgRows,
        ),
      );
    }

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.poPurchaseOrder,
      importFileNameOrCode: po.displayName,
      additionalSections: additionalSections,
    );
  }

  Future<void> _exportPoToPdf(BuildContext context, PurchaseOrderModel po, bool isArabic) async {
    final bool isPalletized = (po.palletPlanItems.isNotEmpty && po.palletPlanItems.any((p) => p.palletCount > 0)) || po.palletCount > 0;

    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    final resolvedPoItems = PoPackingMatcher.resolvePoItemMetrics(
      items: po.items,
      packingListItems: po.packingListItems,
      isPalletized: isPalletized,
      tariffs: tariffs,
    );

    final headers = [
      context.l10n.gitColItemCode,
      context.l10n.poRecColDescription,
      context.l10n.requirementsTsvHeaderHsCode,
      context.l10n.financialSettlementColQty,
      context.l10n.unitCol,
      context.l10n.poQtyPKG,
      context.l10n.poPackageType,
      context.l10n.smartExtractorColUnitPrice,
      context.l10n.freightDataTotalLabel,
      context.l10n.poNetWtKg,
      context.l10n.poGrossWtKg,
      context.l10n.poCBM,
    ];

    final rows = resolvedPoItems.map((resolved) {
      final item = resolved.item;
      return [
        item.itemCode ?? '-',
        item.mainDescription ?? item.descriptionAr,
        resolved.effectiveHsCode != 'UNSPECIFIED' ? resolved.effectiveHsCode : (item.hsCode ?? '-'),
        '${item.quantity}',
        item.unitOfMeasure,
        '${resolved.qtyPkg}',
        resolved.packageType,
        '${po.currencyCode ?? "USD"} ${item.unitPrice.toStringAsFixed(2)}',
        '${po.currencyCode ?? "USD"} ${item.totalPrice.toStringAsFixed(2)}',
        _formatWeight(resolved.netWeightKg),
        _formatWeight(resolved.grossWeightKg),
        resolved.cbm.toStringAsFixed(3),
      ];
    }).toList();

    // Calculate effective totals for accurate metadata
    final double palletPlanCbm = po.palletPlanItems.isNotEmpty
        ? po.palletPlanItems.fold<double>(
            0.0,
            (sum, p) => sum + (p.calculatedCbm > 0 ? p.calculatedCbm : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount),
          )
        : (po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0
            ? (po.palletLengthCm * po.palletWidthCm * po.palletHeightCm / 1000000.0) * po.palletCount
            : (po.palletCount > 0 && po.totalCbm > 0 ? po.totalCbm : 0.0));
    final double palletPlanGrossWeight = po.palletPlanItems.isNotEmpty
        ? po.palletPlanItems.fold<double>(
            0.0,
            (sum, p) => sum + (p.grossWeightPerPalletKg * p.palletCount),
          )
        : (po.palletCount > 0 && po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);
    final int totalPalletCount = po.palletPlanItems.isNotEmpty
        ? po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount)
        : po.palletCount;

    final double effectivePackingListCbm = palletPlanCbm > 0
        ? palletPlanCbm
        : (po.totalCbm > 0
            ? po.totalCbm
            : (po.packingListItems.isNotEmpty
                ? po.packingListItems.fold(0.0, (sum, pl) => sum + (pl.calculatedCbm > 0 ? pl.calculatedCbm : pl.totalCbm))
                : 0.0));
    final double effectivePackingListGrossWeight = palletPlanGrossWeight > 0
        ? palletPlanGrossWeight
        : (po.totalGrossWeightKg > 0
            ? po.totalGrossWeightKg
            : (po.packingListItems.isNotEmpty
                ? po.packingListItems.fold(0.0, (sum, pl) => sum + ((pl.grossWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.grossWeightUnitKg * pl.qtyPkg) : pl.totalGrossWeightKg))
                : 0.0));
    final double effectivePackingListNetWeight = po.totalNetWeightKg > 0
        ? po.totalNetWeightKg
        : (po.packingListItems.isNotEmpty
            ? po.packingListItems.fold(0.0, (sum, pl) => sum + ((pl.netWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.netWeightUnitKg * pl.qtyPkg) : pl.totalNetWeightKg))
            : 0.0);

    final String totalPkgSummary = PoPackingMatcher.formatPackagingSummary(
      packingListItems: po.packingListItems,
      totalPalletCount: totalPalletCount,
      isArabic: isArabic,
    );

    final metadata = <String, String>{
      context.l10n.poPOReferenceName: po.displayName,
      if (po.displayName != po.poNumber)
        context.l10n.poInternalPOCode2: po.poNumber,
      if (po.proformaInvoiceNumber != null && po.proformaInvoiceNumber!.isNotEmpty)
        context.l10n.customsApprovalDocProformaInvoice: po.proformaInvoiceNumber!,
      if (po.companyName != null && po.companyName!.isNotEmpty)
        context.l10n.operationalTsvHeaderImporter: po.companyName!,
      if (po.supplierName != null && po.supplierName!.isNotEmpty)
        context.l10n.draftBlPartySupplier: po.supplierName!,
      if (po.incotermCode != null && po.incotermCode!.isNotEmpty)
        context.l10n.poIncoterms: po.incotermCode!,
      context.l10n.smartExtractorFieldTotalAmount: '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}',
      context.l10n.poTotalCBM2: '${effectivePackingListCbm.toStringAsFixed(3)} m³${totalPalletCount > 0 ? " ($totalPalletCount Pallets)" : ""}',
      context.l10n.smartExtractorFieldTotalGrossWeight: '${_formatWeight(effectivePackingListGrossWeight)} kg',
      context.l10n.poTotalNetWeight: '${_formatWeight(effectivePackingListNetWeight)} kg',
      context.l10n.poTotalQtyPKG2: totalPkgSummary,
    };

    // Section 1: PO Line Items Summary By HS Code
    final Map<String, Map<String, dynamic>> poHsSummaryMap = PoPackingMatcher.buildPoHsSummaryMap(resolvedPoItems);

    final poHsHeaders = [
      context.l10n.requirementsTsvHeaderHsCode,
      context.l10n.financialSettlementColQty,
      context.l10n.poQtyPKG,
      context.l10n.poNetWtKg,
      context.l10n.poGrossWtKg,
      context.l10n.freightBookingCbmVolumeLabel,
      context.l10n.smartExtractorFieldTotalAmount,
      context.l10n.poDutyVAT,
    ];

    final poHsRows = poHsSummaryMap.values.map((s) {
      return [
        '${s['hs_code']}',
        '${s['qty']}',
        '${s['qty_pkg']}',
        _formatWeight(s['total_net'] as double),
        _formatWeight(s['total_gross'] as double),
        (s['total_cbm'] as double).toStringAsFixed(3),
        '${po.currencyCode ?? "USD"} ${(s['total_price'] as double).toStringAsFixed(2)}',
        '${s['duty_rate']}% / ${s['vat_rate']}%',
      ];
    }).toList();

    final List<TableExportSection> additionalSections = [
      TableExportSection(
        title: context.l10n.poPOLineItemsSummaryByHS,
        headers: poHsHeaders,
        rows: poHsRows,
      ),
    ];

    // Section 2: Packing List Summary By HS Code (if packing list exists)
    if (po.packingListItems.isNotEmpty) {
      final Map<String, Map<String, dynamic>> hsSummaryMap = {};
      for (final p in po.packingListItems) {
        final hs = p.hsCode.isNotEmpty ? p.hsCode : 'UNSPECIFIED';
        if (!hsSummaryMap.containsKey(hs)) {
          hsSummaryMap[hs] = {
            'hs_code': hs,
            'qty_pcs': 0.0,
            'qty_pkg': 0.0,
            'total_net': 0.0,
            'total_gross': 0.0,
            'total_cbm': 0.0,
          };
        }
        final double plNet = (p.netWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.netWeightUnitKg) : p.totalNetWeightKg;
        final double plGross = (p.grossWeightUnitKg > 0 && p.qtyPkg > 0) ? (p.qtyPkg * p.grossWeightUnitKg) : p.totalGrossWeightKg;
        final double plCbm = p.calculatedCbm > 0 ? p.calculatedCbm : p.totalCbm;
        hsSummaryMap[hs]!['qty_pcs'] += p.qtyPcs;
        hsSummaryMap[hs]!['qty_pkg'] += p.qtyPkg;
        hsSummaryMap[hs]!['total_net'] += plNet;
        hsSummaryMap[hs]!['total_gross'] += plGross;
        hsSummaryMap[hs]!['total_cbm'] += plCbm;
      }

      final plHsHeaders = [
        context.l10n.requirementsTsvHeaderHsCode,
        context.l10n.poQtyPcs,
        context.l10n.poQtyPKG,
        context.l10n.poNetWtKg,
        context.l10n.poGrossWtKg,
        context.l10n.freightBookingCbmVolumeLabel,
      ];

      final plHsRows = hsSummaryMap.values.map((s) {
        return [
          '${s['hs_code']}',
          '${s['qty_pcs']}',
          '${s['qty_pkg']}',
          _formatWeight(s['total_net'] as double),
          _formatWeight(s['total_gross'] as double),
          (s['total_cbm'] as double).toStringAsFixed(3),
        ];
      }).toList();

      additionalSections.add(
        TableExportSection(
          title: context.l10n.poPackingListSummaryByHSCode,
          headers: plHsHeaders,
          rows: plHsRows,
        ),
      );
    }

    // Section 3: Packing List Summary By Package Type (if packing list exists)
    final packageTypeSummaryMap = PoPackingMatcher.buildPackingTypeSummaryMap(po.packingListItems);
    if (packageTypeSummaryMap.isNotEmpty) {
      final pkgHeaders = [
        context.l10n.poPackageType,
        context.l10n.poRecReportPackages,
        context.l10n.poNetWtKg,
        context.l10n.poGrossWtKg,
        context.l10n.freightBookingCbmVolumeLabel,
      ];

      final pkgRows = packageTypeSummaryMap.values.map((s) {
        final double qty = (s['qty_pkg'] as num).toDouble();
        final String qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
        return [
          '${s['package_type']}',
          qtyStr,
          _formatWeight(s['total_net'] as double),
          _formatWeight(s['total_gross'] as double),
          (s['total_cbm'] as double).toStringAsFixed(3),
        ];
      }).toList();

      additionalSections.add(
        TableExportSection(
          title: context.l10n.poPackingListSummaryByPackageType,
          headers: pkgHeaders,
          rows: pkgRows,
        ),
      );
    }

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.poPurchaseOrder,
      importFileNameOrCode: po.displayName,
      additionalSections: additionalSections,
      headerContext: TableExportHeaderContext(
        title: context.l10n.poPurchaseOrderItemsSpecification,
        subtitle: 'Sorour Logistics ERP — ${po.displayName}',
        metadata: metadata,
      ),
    );
  }

  Widget _buildPackageTypeSummaryTable({
    required BuildContext context,
    required Map<String, Map<String, dynamic>> packageTypeSummaryMap,
    required bool isDark,
    required bool isArabic,
  }) {
    if (packageTypeSummaryMap.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.poPackingListSummaryByPackageType,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 6),
        SelectionArea(
          child: Table(
            border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
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
                decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      context.l10n.poPackageType,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      context.l10n.poRecReportPackages,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      context.l10n.poNetWtKg,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      context.l10n.poGrossWtKg,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      context.l10n.freightBookingCbmVolumeLabel,
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
                final String qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
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
                        '${_formatWeight(net)} kg',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${_formatWeight(gross)} kg',
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
                        style: const TextStyle(fontSize: 11, color: AppTheme.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 16),
                          tooltip: context.l10n.poCopyRowForExcelTSV,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => TableCopyHelper.copyRow(
                            context,
                            [pkgType, qtyStr, net, gross, cbm],
                            headers: ['Package Type', 'Total Packages', 'Net Weight', 'Gross Weight', 'CBM'],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isDark = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        CopyableText(
          value,
          showIcon: false,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
        ),
      ],
    );
  }

  static List<CargoItem> _extractCargoItemsFromPo(PurchaseOrderModel po) {
    final hasPalletPlan = po.palletPlanItems.isNotEmpty && po.palletPlanItems.any((p) => p.palletCount > 0);
    final hasSinglePallet = po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0;
    List<CargoItem> cargoItems = [];

    if (hasPalletPlan) {
      final double totalGross = po.packingListItems.fold<double>(
        0.0,
        (sum, p) => sum + (p.totalGrossWeightKg > 0 ? p.totalGrossWeightKg : (p.qtyPkg * p.grossWeightUnitKg)),
      );
      final int totalPallets = po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount);
      final double defaultPalletWeight = totalPallets > 0 && totalGross > 0 ? (totalGross / totalPallets) : 137.5;

      int globalIdx = 1;
      for (final pLine in po.palletPlanItems) {
        final pL = pLine.lengthCm > 0 ? pLine.lengthCm : 120.0;
        final pW = pLine.widthCm > 0 ? pLine.widthCm : 80.0;
        final pH = pLine.heightCm > 0 ? pLine.heightCm : 150.0;
        final pWt = pLine.grossWeightPerPalletKg > 0 ? pLine.grossWeightPerPalletKg : defaultPalletWeight;

        for (int i = 0; i < pLine.palletCount; i++) {
          cargoItems.add(CargoItem(
            itemId: 'PLT-$globalIdx',
            length: pL,
            width: pW,
            height: pH,
            weight: pWt,
            isStackable: pLine.isStackable,
            rotate: true,
            packageType: pLine.palletType,
            description: 'بالتة #$globalIdx (${pLine.palletType})${pLine.isStackable ? "" : " [Floor Only]"}',
          ));
          globalIdx++;
        }
      }
    } else if (hasSinglePallet) {
      final double pWt = po.totalGrossWeightKg > 0 ? (po.totalGrossWeightKg / po.palletCount) : 137.5;
      for (int i = 0; i < po.palletCount; i++) {
        cargoItems.add(CargoItem(
          itemId: 'PLT-${i + 1}',
          length: po.palletLengthCm,
          width: po.palletWidthCm,
          height: po.palletHeightCm,
          weight: pWt,
          isStackable: po.isPalletStackable,
          rotate: true,
          packageType: po.palletType,
          description: 'بالتة #${i + 1} (${po.palletType})${po.isPalletStackable ? "" : " [Floor Only]"}',
        ));
      }
    } else if (po.packingListItems.isNotEmpty) {
      int globalIdx = 1;
      for (final p in po.packingListItems) {
        final lCm = p.unit == 'mm' ? p.lengthCm / 10.0 : (p.unit == 'm' ? p.lengthCm * 100.0 : p.lengthCm);
        final wCm = p.unit == 'mm' ? p.widthCm / 10.0 : (p.unit == 'm' ? p.widthCm * 100.0 : p.widthCm);
        final hCm = p.unit == 'mm' ? p.heightCm / 10.0 : (p.unit == 'm' ? p.heightCm * 100.0 : p.heightCm);
        final int count = p.qtyPkg > 0 ? p.qtyPkg.toInt() : 1;
        final double unitGrossWt = p.grossWeightUnitKg > 0
            ? p.grossWeightUnitKg
            : (p.totalGrossWeightKg > 0 ? (p.totalGrossWeightKg / count) : 10.0);

        for (int i = 0; i < count; i++) {
          cargoItems.add(CargoItem(
            itemId: '$globalIdx',
            length: lCm > 0 ? lCm : 100.0,
            width: wCm > 0 ? wCm : 80.0,
            height: hCm > 0 ? hCm : 60.0,
            weight: unitGrossWt,
            isStackable: p.isStackable,
            rotate: true,
            packageType: p.packageType,
            description: count > 1 ? '${p.itemCode} (طرد ${i + 1}/$count)' : p.itemCode,
          ));
          globalIdx++;
        }
      }
    }
    return cargoItems;
  }

  Widget _buildPo3dLoadPlannerTab(
    BuildContext context,
    PurchaseOrderModel po,
    bool isDark,
    bool isArabic,
    AppLocalizations l,
  ) {
    final cargoItems = _extractCargoItemsFromPo(po);

    if (cargoItems.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.view_in_ar_rounded, size: 48, color: AppTheme.orange),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.poNoPackingListOrPalletData,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.poPleaseAddPackingListOrPallet,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: context.l10n.poEditPOAddPackingList,
                icon: Icons.edit,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: () {
                  Navigator.pop(context);
                  onEdit?.call();
                },
              ),
            ],
          ),
        ),
      );
    }

    String viewProjection = 'both';
    bool showDetailedCoordinates = false;
    bool? activeStackingMode = cargoItems.any((i) => !i.isStackable) ? null : true;
    CargoOrientationPreference activeOrientationMode = CargoOrientationPreference.smartHybrid;
    final GlobalKey tab3dRepaintKey = GlobalKey();

    return StatefulBuilder(
      builder: (ctx, setTabState) {
        final plan = ContainerRequirementEngine.planShipment(
          cargoItems,
          forceStackable: activeStackingMode,
          forceOrientation: activeOrientationMode,
        );

        final totalPkgs = cargoItems.length;
        final stackableInActive = activeStackingMode == true
            ? totalPkgs
            : (activeStackingMode == false ? 0 : cargoItems.where((c) => c.isStackable).length);
        final nonStackableInActive = totalPkgs - stackableInActive;

        final totalPlanWeight = plan.fold(0.0, (s, p) => s + p.totalWeight);
        final totalPlanVolume = plan.fold(0.0, (s, p) => s + p.totalVolume);

        final Map<String, int> containerCounts = {};
        for (final p in plan) {
          if (p.containerCode != 'FAILED') {
            containerCounts[p.containerCode] = (containerCounts[p.containerCode] ?? 0) + 1;
          }
        }
        final fleetSummary = containerCounts.isEmpty
            ? (context.l10n.poNoSuitableContainers)
            : containerCounts.entries.map((e) => '${e.value} x ${e.key}').join(' + ');

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Export Actions Bar (PNG & PDF)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: context.l10n.poDownloadSimulationViewsPNG,
                    icon: Icons.image_outlined,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: () async {
                      await ContainerLoadPlanExportService.exportSimulationImage(
                        context: context,
                        repaintKey: tab3dRepaintKey,
                        displayName: '${po.displayName} - 3D Simulation',
                        isArabic: isArabic,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: context.l10n.poDownloadLoadingPlanPDF,
                    icon: Icons.picture_as_pdf_outlined,
                    variant: AppButtonVariant.danger,
                    size: AppButtonSize.small,
                    onPressed: () async {
                      await ContainerLoadPlanExportService.exportLoadingPlanPdf(
                        context: context,
                        repaintKey: tab3dRepaintKey,
                        displayName: po.displayName,
                        poNumber: po.poNumber,
                        companyName: po.companyName,
                        supplierName: po.supplierName,
                        plan: plan,
                        fleetSummary: fleetSummary,
                        totalPlanWeight: totalPlanWeight,
                        totalPlanVolume: totalPlanVolume,
                        totalPkgs: totalPkgs,
                        isArabic: isArabic,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Controls & Stacking Filter Row (Responsive Wrap)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoalSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '🔄 ${l.stackingSimulationModeLabel}:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                        ChoiceChip(
                          label: Text('✨ ${l.smartHybridOption}'),
                          selected: activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode == true,
                          selectedColor: AppTheme.emerald,
                          labelStyle: TextStyle(
                            color: (activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode == true) ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setTabState(() {
                                activeOrientationMode = CargoOrientationPreference.smartHybrid;
                                activeStackingMode = true;
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Text('📐 ${l.flatOnlyOption}'),
                          selected: activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode == true,
                          selectedColor: AppTheme.cobalt,
                          labelStyle: TextStyle(
                            color: (activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode == true) ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setTabState(() {
                                activeOrientationMode = CargoOrientationPreference.flatOnly;
                                activeStackingMode = true;
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Text('🚫 ${l.simulationModeFloorOnly}'),
                          selected: activeStackingMode == false,
                          selectedColor: AppTheme.wcagOrange,
                          labelStyle: TextStyle(
                            color: activeStackingMode == false ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setTabState(() {
                                activeStackingMode = false;
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Text('🔀 ${l.simulationModeActualMixed}'),
                          selected: activeStackingMode == null,
                          selectedColor: AppTheme.charcoal,
                          labelStyle: TextStyle(
                            color: activeStackingMode == null ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setTabState(() {
                                activeStackingMode = null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '👁️ ${l.projectionLabel}:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                        ChoiceChip(
                          label: Text(context.l10n.poBothViews),
                          selected: viewProjection == 'both',
                          selectedColor: AppTheme.cobalt,
                          labelStyle: TextStyle(
                            color: viewProjection == 'both' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) setTabState(() => viewProjection = 'both');
                          },
                        ),
                        ChoiceChip(
                          label: Text('📐 ${l.sideViewProjection}'),
                          selected: viewProjection == 'side',
                          selectedColor: AppTheme.cobalt,
                          labelStyle: TextStyle(
                            color: viewProjection == 'side' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) setTabState(() => viewProjection = 'side');
                          },
                        ),
                        ChoiceChip(
                          label: Text('🔝 ${l.topViewProjection}'),
                          selected: viewProjection == 'top',
                          selectedColor: AppTheme.cobalt,
                          labelStyle: TextStyle(
                            color: viewProjection == 'top' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) setTabState(() => viewProjection = 'top');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Fleet KPI Summary Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.charcoal.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.charcoal.withValues(alpha: 0.12)),
                ),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceAround,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_boat_rounded, color: AppTheme.cobalt, size: 20),
                        const SizedBox(width: 6),
                        Text(l.requiredContainersSummary(fleetSummary), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal, size: 18),
                        const SizedBox(width: 6),
                        Text(l.totalPackagesSummary(totalPkgs, stackableInActive, nonStackableInActive), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : null)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.scale_outlined, color: AppTheme.emerald, size: 18),
                        const SizedBox(width: 6),
                        Text(l.totalWeightSummary(_formatWeight(totalPlanWeight)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.view_in_ar, color: AppTheme.orange, size: 18),
                        const SizedBox(width: 6),
                        Text(l.totalVolumeSummary(totalPlanVolume.toStringAsFixed(3)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.orange)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Plan Containers List (Wrapped in RepaintBoundary for PNG/PDF Export)
              RepaintBoundary(
                key: tab3dRepaintKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: plan.asMap().entries.map((pEntry) {
                    final pIdx = pEntry.key;
                    final res = pEntry.value;
                    if (res.containerCode == 'FAILED') {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.crimsonLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppTheme.crimson : AppTheme.crimsonBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                res.failureReason ?? l.packingFailureTitle,
                                style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final spacePct = (res.totalVolume / res.spec.internalVolumeCbm * 100);
                    final weightPct = (res.totalWeight / res.spec.maxPayloadKg * 100);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    l.containerCardHeader(pIdx + 1, res.spec.code, res.placedItems.length, spacePct.toStringAsFixed(1), weightPct.toStringAsFixed(1)),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    l.internalDimensionsLabel(res.spec.internalLength.toStringAsFixed(0), res.spec.internalWidth.toStringAsFixed(0), res.spec.internalHeight.toStringAsFixed(0)),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (viewProjection == 'both') ...[
                              // Side View (Left Wall Removed)
                              Container(
                                height: 190,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppTheme.charcoal,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: CustomPaint(
                                  painter: ContainerLoadPlanPainter(plan: res, isTopView: false),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Top View (Roof Removed)
                              Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppTheme.charcoal,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: CustomPaint(
                                  painter: ContainerLoadPlanPainter(plan: res, isTopView: true),
                                ),
                              ),
                            ] else ...[
                              Container(
                                height: 320,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppTheme.charcoal,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: CustomPaint(
                                  painter: ContainerLoadPlanPainter(plan: res, isTopView: viewProjection == 'top'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),

                            // Placed Items Details Table (Aggregated by Item Rule)
                            Theme(
                              data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: true,
                                tilePadding: EdgeInsets.zero,
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      showDetailedCoordinates
                                          ? (context.l10n.poDetailedPlacementCoordinatesPkgs(res.placedItems.length))
                                          : (context.l10n.poGroupedItemsItemsTotalPkgs(res.groupedItems.length, res.placedItems.length)),
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    ),
                                    AppButton(
                                      label: showDetailedCoordinates ? (context.l10n.poGroupByItems) : (context.l10n.poDetailedCoordinates),
                                      icon: showDetailedCoordinates ? Icons.table_chart_outlined : Icons.format_list_numbered,
                                      variant: AppButtonVariant.secondary,
                                      size: AppButtonSize.small,
                                      onPressed: () => setTabState(() => showDetailedCoordinates = !showDetailedCoordinates),
                                    ),
                                  ],
                                ),
                                children: [
                                  if (!showDetailedCoordinates)
                                    Table(
                                      border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                                      columnWidths: const {
                                        0: FlexColumnWidth(0.6),
                                        1: FlexColumnWidth(2.5),
                                        2: FlexColumnWidth(1.2),
                                        3: FlexColumnWidth(1.6),
                                        4: FlexColumnWidth(1.2),
                                        5: FlexColumnWidth(1.8),
                                        6: FlexColumnWidth(1.2),
                                        7: FlexColumnWidth(1.2),
                                      },
                                      children: [
                                        TableRow(
                                          decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                          children: [
                                            const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            PoHeaderCell(context.l10n.poItemCode, fontSize: 11),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poPkgType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poDimsCm, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.qtyCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poGrossWt2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poCBM2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poStack, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                          ],
                                        ),
                                        ...res.groupedItems.asMap().entries.map((entry) {
                                          final idx = entry.key + 1;
                                          final g = entry.value;
                                          return TableRow(
                                            children: [
                                              Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text(g.itemCodeOrDesc, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text(g.packageType, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${g.length.toStringAsFixed(0)} × ${g.width.toStringAsFixed(0)} × ${g.height.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text('${g.count}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt), textAlign: TextAlign.center),
                                                ),
                                              ),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${g.totalWeight.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${g.volumeM3.toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11, color: AppTheme.orange, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text(g.isStackable ? (context.l10n.poYes) : (context.l10n.poFloor), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: g.isStackable ? AppTheme.emerald : AppTheme.crimson), textAlign: TextAlign.center)),
                                            ],
                                          );
                                        }),
                                      ],
                                    )
                                  else
                                    Table(
                                      border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                                      columnWidths: const {
                                        0: FlexColumnWidth(0.8),
                                        1: FlexColumnWidth(2.2),
                                        2: FlexColumnWidth(1.8),
                                        3: FlexColumnWidth(1.2),
                                        4: FlexColumnWidth(2.0),
                                        5: FlexColumnWidth(1.2),
                                      },
                                      children: [
                                        TableRow(
                                          decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                          children: [
                                            const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            PoHeaderCell(l.thPackageCode, fontSize: 11),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.thDimensions, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.thWeight, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.thCoordinates, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.thStacking, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                          ],
                                        ),
                                        ...res.placedItems.asMap().entries.map((entry) {
                                          final idx = entry.key + 1;
                                          final item = entry.value;
                                          return TableRow(
                                            children: [
                                              Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text(item.item.description ?? item.item.itemId, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('${item.length.toStringAsFixed(0)} × ${item.width.toStringAsFixed(0)} × ${item.height.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text(item.item.weight.toStringAsFixed(1), style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text('X: ${item.x.toStringAsFixed(0)} | Y: ${item.y.toStringAsFixed(0)} | Z: ${item.z.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.center)),
                                              Padding(padding: const EdgeInsets.all(6), child: Text(item.item.isStackable ? (context.l10n.poYes) : (context.l10n.poFloor), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.item.isStackable ? AppTheme.emerald : AppTheme.crimson), textAlign: TextAlign.center)),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
