import 'package:flutter/material.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import '../po_table_cells.dart';
import 'po_report_preview_helpers.dart';

/// Commercial Invoice Line Items table for the PO preview dialog.
class POReportInvoiceItemsTable extends StatelessWidget {
  final List<POLineItemModel> items;
  final List<CustomsTariffModel> tariffs;
  final String currency;
  final bool isArabic;
  final bool isDark;

  const POReportInvoiceItemsTable({
    super.key,
    required this.items,
    this.tariffs = const [],
    required this.currency,
    required this.isArabic,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final totalInvoiceQty = items.fold(0.0, (s, i) => s + i.quantity);
    final totalInvoicePrice = items.fold(
      0.0,
      (s, i) => s + (i.totalPrice > 0 ? i.totalPrice : (i.quantity * i.unitPrice)),
    );

    return ReportTableCard(
      minWidth: 850,
      isDark: isDark,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite, width: 1),
        ),
        columnWidths: const {
          0: FixedColumnWidth(36),
          1: FixedColumnWidth(100),
          2: FixedColumnWidth(160),
          3: FixedColumnWidth(220),
          4: FixedColumnWidth(110),
          5: FixedColumnWidth(90),
          6: FixedColumnWidth(100),
          7: FixedColumnWidth(115),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.charcoalSurface),
            children: [
              const ReportPreviewHeaderCell('#'),
              ReportPreviewHeaderCell(l.poReportColItemCode),
              ReportPreviewHeaderCell(l.mainDescription),
              ReportPreviewHeaderCell(l.poReportColDescription),
              ReportPreviewHeaderCell(l.poReportColHsCode),
              ReportPreviewHeaderCell(l.poReportColQtyUnit),
              ReportPreviewHeaderCell(l.poReportColUnitPrice),
              ReportPreviewHeaderCell(l.poReportColTotalAmount),
            ],
          ),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final itm = entry.value;
            String hs = itm.hsCode ?? '';
            if (hs.isEmpty && itm.tariffId != null) {
              final match = tariffs.where((t) => t.tariffId == itm.tariffId).firstOrNull;
              if (match != null) hs = match.hsCode;
            }
            final itemTotal = (itm.totalPrice > 0) ? itm.totalPrice : (itm.quantity * itm.unitPrice);
            final desc = isArabic
                ? (itm.descriptionAr.isNotEmpty ? itm.descriptionAr : (itm.descriptionEn ?? '-'))
                : (itm.descriptionEn?.isNotEmpty == true ? itm.descriptionEn! : itm.descriptionAr);
            final mainDesc = itm.mainDescription?.isNotEmpty == true ? itm.mainDescription! : '-';

            return TableRow(
              decoration: poZebraRowDecoration(idx, isDark),
              children: [
                ReportPreviewDataCell('${idx + 1}', align: TextAlign.center),
                ReportPreviewDataCell(itm.itemCode ?? '-', isBold: true, color: AppTheme.cobalt),
                ReportPreviewDataCell(mainDesc, isBold: itm.mainDescription?.isNotEmpty == true, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                ReportPreviewDataCell(desc),
                ReportPreviewDataCell(
                  hs.isNotEmpty ? hs : context.l10n.poUnregistered,
                  color: hs.isNotEmpty ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal) : AppTheme.crimson,
                ),
                ReportPreviewDataCell('${itm.quantity.toStringAsFixed(0)} ${itm.unitOfMeasure}'),
                ReportPreviewDataCell('${itm.unitPrice.toStringAsFixed(2)} $currency'),
                ReportPreviewDataCell('${itemTotal.toStringAsFixed(2)} $currency', isBold: true),
              ],
            );
          }),
          TableRow(
            decoration: BoxDecoration(color: isDark ? AppTheme.cobaltMedium : AppTheme.cobaltLight.withValues(alpha: 0.5)),
            children: [
              const ReportPreviewDataCell(''),
              ReportPreviewDataCell(l.poReportGrandTotal, isBold: true, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
              const ReportPreviewDataCell(''),
              ReportPreviewDataCell(l.poReportItemsCountUnit(items.length), isBold: true),
              const ReportPreviewDataCell(''),
              ReportPreviewDataCell('${totalInvoiceQty.toStringAsFixed(0)} pcs', isBold: true),
              const ReportPreviewDataCell(''),
              ReportPreviewDataCell('${totalInvoicePrice.toStringAsFixed(2)} $currency', isBold: true, color: AppTheme.emerald),
            ],
          ),
        ],
      ),
    );
  }
}

/// Detailed Packing List table for the PO preview dialog.
class POReportPackingListTable extends StatelessWidget {
  final List<PackingListItemModel> packingItems;
  final List<POLineItemModel> items;
  final bool isDark;

  const POReportPackingListTable({
    super.key,
    required this.packingItems,
    required this.items,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final totalPkgSum = packingItems.fold<double>(0.0, (s, p) => s + p.qtyPkg);
    final totalPcsSum = packingItems.fold<double>(0.0, (s, p) => s + p.qtyPcs);
    final totalGrossSum = packingItems.fold<double>(0.0, (s, p) => s + p.computedTotalGrossWeightKg);
    final totalCbmSum = packingItems.fold<double>(0.0, (s, p) => s + p.calculatedCbm);

    return ReportTableCard(
      minWidth: 950,
      isDark: isDark,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite, width: 1),
        ),
        columnWidths: const {
          0: FixedColumnWidth(36),
          1: FixedColumnWidth(100),
          2: FixedColumnWidth(140),
          3: FixedColumnWidth(180),
          4: FixedColumnWidth(80),
          5: FixedColumnWidth(90),
          6: FixedColumnWidth(100),
          7: FixedColumnWidth(90),
          8: FixedColumnWidth(85),
          9: FixedColumnWidth(80),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.charcoalSurface),
            children: [
              const ReportPreviewHeaderCell('#'),
              ReportPreviewHeaderCell(l.poReportColItemCode),
              ReportPreviewHeaderCell(l.mainDescription),
              ReportPreviewHeaderCell(l.poReportColDescription),
              ReportPreviewHeaderCell(l.poReportColPkgType),
              ReportPreviewHeaderCell(l.poReportTotalPkgsAndPcs),
              ReportPreviewHeaderCell(l.poReportColDimensions),
              ReportPreviewHeaderCell(l.poReportGrossWeight),
              ReportPreviewHeaderCell(l.poReportVolumeCbm),
              ReportPreviewHeaderCell(l.poReportColStackable),
            ],
          ),
          ...packingItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final p = entry.value;
            final grossTot = p.computedTotalGrossWeightKg;
            final dimStr = (p.lengthCm > 0 && p.widthCm > 0 && p.heightCm > 0)
                ? '${p.lengthCm.toStringAsFixed(0)}×${p.widthCm.toStringAsFixed(0)}×${p.heightCm.toStringAsFixed(0)}'
                : l.poReportDirectVolume;

            String mainDesc = p.mainDescription ?? '';
            if (mainDesc.isEmpty) {
              final matchedItem = items.where((i) => i.itemCode != null && i.itemCode == p.itemCode).firstOrNull;
              if (matchedItem != null && matchedItem.mainDescription?.isNotEmpty == true) {
                mainDesc = matchedItem.mainDescription!;
              }
            }

            return TableRow(
              decoration: poZebraRowDecoration(idx, isDark),
              children: [
                ReportPreviewDataCell('${idx + 1}', align: TextAlign.center),
                ReportPreviewDataCell(p.itemCode, isBold: true, color: AppTheme.cobalt),
                ReportPreviewDataCell(mainDesc.isNotEmpty ? mainDesc : '-', isBold: mainDesc.isNotEmpty, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                ReportPreviewDataCell(p.description != null && p.description!.isNotEmpty ? p.description! : '-'),
                ReportPreviewDataCell(p.packageType),
                ReportPreviewDataCell('${p.qtyPkg.toStringAsFixed(0)} / ${p.qtyPcs.toStringAsFixed(0)}'),
                ReportPreviewDataCell(dimStr, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                ReportPreviewDataCell(formatPOWeight(grossTot)),
                ReportPreviewDataCell(p.calculatedCbm.toStringAsFixed(3)),
                ReportPreviewDataCell(
                  p.isStackable ? l.poReportStackableYes : l.poReportStackableNo,
                  color: p.isStackable ? (isDark ? AppTheme.emerald : AppTheme.wcagEmerald) : AppTheme.wcagOrange,
                ),
              ],
            );
          }),
          TableRow(
            decoration: BoxDecoration(color: isDark ? AppTheme.cobaltMedium : AppTheme.cobaltLight.withValues(alpha: 0.5)),
            children: [
              const ReportPreviewDataCell(''),
              ReportPreviewDataCell(l.poReportTotalPacking, isBold: true, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
              const ReportPreviewDataCell(''),
              ReportPreviewDataCell(l.poReportRowsCountUnit(packingItems.length), isBold: true),
              const ReportPreviewDataCell(''),
              ReportPreviewDataCell('${l.poReportPackagesCountUnit(totalPkgSum.toInt())} / ${l.poReportPiecesCountUnit(totalPcsSum.toInt())}', isBold: true),
              const ReportPreviewDataCell(''),
              ReportPreviewDataCell('${formatPOWeight(totalGrossSum)} kg', isBold: true, color: AppTheme.orange),
              ReportPreviewDataCell('${totalCbmSum.toStringAsFixed(3)} m³', isBold: true, color: AppTheme.cobalt),
              const ReportPreviewDataCell(''),
            ],
          ),
        ],
      ),
    );
  }
}

/// Package Type Summary breakdown table.
class POReportPackageTypeSummaryTable extends StatelessWidget {
  final Map<String, Map<String, dynamic>> packageTypeSummaryMap;
  final bool isArabic;
  final bool isDark;

  const POReportPackageTypeSummaryTable({
    super.key,
    required this.packageTypeSummaryMap,
    required this.isArabic,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (packageTypeSummaryMap.isEmpty) return const SizedBox.shrink();

    return ReportTableCard(
      minWidth: 700,
      isDark: isDark,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: FlexColumnWidth(2.2),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1.2),
          3: FlexColumnWidth(1.2),
          4: FlexColumnWidth(1.2),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
            children: [
              ReportPreviewHeaderCell(context.l10n.poPackageType),
              ReportPreviewHeaderCell(context.l10n.poRecReportPackages),
              ReportPreviewHeaderCell(context.l10n.poNetWtKg),
              ReportPreviewHeaderCell(context.l10n.poGrossWtKg),
              ReportPreviewHeaderCell(context.l10n.freightBookingCbmVolumeLabel),
            ],
          ),
          ...packageTypeSummaryMap.values.map((pkgSummary) {
            final pkgType = '${pkgSummary['package_type']}';
            final count = pkgSummary['qty_pkg'] as int;
            final net = pkgSummary['total_net'] as double;
            final gross = pkgSummary['total_gross'] as double;
            final cbm = pkgSummary['total_cbm'] as double;

            return TableRow(
              children: [
                ReportPreviewDataCell(pkgType, isBold: true, color: AppTheme.cobalt),
                ReportPreviewDataCell('$count', isBold: true),
                ReportPreviewDataCell('${formatPOWeight(net)} kg'),
                ReportPreviewDataCell('${formatPOWeight(gross)} kg', isBold: true),
                ReportPreviewDataCell('${cbm.toStringAsFixed(3)} m³', color: AppTheme.cobalt, isBold: true),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// Master Pallet Plan table for the PO preview dialog.
class POReportPalletPlanTable extends StatelessWidget {
  final List<PalletPlanItemModel> palletItems;
  final bool isDark;

  const POReportPalletPlanTable({
    super.key,
    required this.palletItems,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final int palletSum = palletItems.fold<int>(0, (s, p) => s + p.palletCount);
    final double weightSum = palletItems.fold<double>(0.0, (s, p) => s + p.totalWeightKg);
    final double cbmSum = palletItems.fold<double>(0.0, (s, p) => s + p.calculatedCbm);

    return ReportTableCard(
      minWidth: 700,
      isDark: isDark,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite, width: 1),
        ),
        columnWidths: const {
          0: FixedColumnWidth(36),
          1: FixedColumnWidth(160),
          2: FixedColumnWidth(80),
          3: FixedColumnWidth(110),
          4: FixedColumnWidth(90),
          5: FixedColumnWidth(90),
          6: FixedColumnWidth(130),
          7: FixedColumnWidth(160),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.charcoalSurface),
            children: [
              const ReportPreviewHeaderCell('#'),
              ReportPreviewHeaderCell(l.palletTypeCol),
              ReportPreviewHeaderCell(l.palletCountCol),
              ReportPreviewHeaderCell(l.palletDimensionsCol),
              ReportPreviewHeaderCell(l.palletWeightCol),
              ReportPreviewHeaderCell(l.palletVolumeCol),
              ReportPreviewHeaderCell(l.palletStackingInstructionsCol),
              ReportPreviewHeaderCell(l.notes),
            ],
          ),
          ...palletItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final p = entry.value;
            return TableRow(
              decoration: poZebraRowDecoration(idx, isDark),
              children: [
                ReportPreviewDataCell('${idx + 1}', align: TextAlign.center),
                ReportPreviewDataCell(p.palletType, isBold: true),
                ReportPreviewDataCell('${p.palletCount} ${l.poReportPalletsCountUnit(p.palletCount)}', isBold: true, color: AppTheme.cobalt),
                ReportPreviewDataCell('${p.lengthCm.toStringAsFixed(0)}×${p.widthCm.toStringAsFixed(0)}×${p.heightCm.toStringAsFixed(0)}'),
                ReportPreviewDataCell(formatPOWeight(p.totalWeightKg)),
                ReportPreviewDataCell(p.calculatedCbm.toStringAsFixed(3)),
                ReportPreviewDataCell(
                  p.isStackable ? l.poReportStackableYes : l.poReportStackableNo,
                  color: p.isStackable ? (isDark ? AppTheme.emerald : AppTheme.wcagEmerald) : AppTheme.wcagOrange,
                ),
                ReportPreviewDataCell(p.notes != null && p.notes!.isNotEmpty ? p.notes! : '-'),
              ],
            );
          }),
          TableRow(
            decoration: BoxDecoration(color: isDark ? AppTheme.cobaltMedium : AppTheme.cobaltLight.withValues(alpha: 0.5)),
            children: [
              const ReportPreviewDataCell(''),
              ReportPreviewDataCell(l.poReportTotalPallets, isBold: true, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
              ReportPreviewDataCell('$palletSum ${l.poReportPalletsCountUnit(palletSum)}', isBold: true, color: AppTheme.cobalt),
              const ReportPreviewDataCell(''),
              ReportPreviewDataCell('${formatPOWeight(weightSum)} kg', isBold: true),
              ReportPreviewDataCell('${cbmSum.toStringAsFixed(3)} m³', isBold: true, color: AppTheme.cobalt),
              const ReportPreviewDataCell(''),
              const ReportPreviewDataCell(''),
            ],
          ),
        ],
      ),
    );
  }
}
