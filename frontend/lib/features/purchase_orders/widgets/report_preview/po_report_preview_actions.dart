import 'package:flutter/material.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/services/display_name_resolver.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';
import 'package:frontend/core/widgets/copyable_data_helper.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'po_report_preview_helpers.dart';
import 'po_report_preview_visual_planner.dart';

/// Formats and copies the complete PO report text representation to clipboard.
void copyPOReportTextToClipboard({
  required BuildContext context,
  required AppLocalizations l,
  required bool isArabic,
  required String poNumber,
  String? piNumber,
  String? acidNumber,
  required DateTime orderDate,
  required String companyName,
  String? companyTaxId,
  required String supplierName,
  String? supplierCountry,
  required String incoterm,
  required String currency,
  required double exchangeRate,
  String? countryOfOrigin,
  String? projectName,
  String? importFileCode,
  required List<POLineItemModel> items,
  required List<PackingListItemModel> packingItems,
  required List<PalletPlanItemModel> palletItems,
  required POReportPreviewMetrics metrics,
}) {
  final sb = StringBuffer();
  sb.writeln('================================================================');
  sb.writeln('Sorour Logistics ERP — ${l.poReportHeaderDocumentTitle}');
  sb.writeln('================================================================');
  sb.writeln('${l.poReportPoNumber}: $poNumber');
  if (piNumber != null && piNumber.isNotEmpty) sb.writeln('${l.poReportPiNumber}: $piNumber');
  if (acidNumber != null && acidNumber.isNotEmpty) sb.writeln('${l.poReportAcidNumber}: $acidNumber');
  sb.writeln('${l.poReportOrderDate}: ${orderDate.toIso8601String().substring(0, 10)}');
  sb.writeln('${l.poReportBuyer}: $companyName (${l.poReportTaxId}: ${companyTaxId ?? "N/A"})');
  sb.writeln('${l.poReportSeller}: $supplierName (${l.poReportSupplierCountry}: ${supplierCountry ?? countryOfOrigin ?? "N/A"})');
  sb.writeln('${l.poReportIncoterms}: $incoterm | ${l.currency}: $currency | ${l.poReportExchangeRate}: $exchangeRate EGP');
  if (projectName != null && projectName.isNotEmpty) {
    sb.writeln('${isArabic ? "المشروع" : "Project"}: $projectName');
  }
  if (importFileCode != null && importFileCode.isNotEmpty) {
    sb.writeln(
      '${l.poReportImportFile}: ${DisplayNameResolver.resolveShipmentTitleByCode(importFileCode, isArabic: isArabic)}',
    );
  }
  sb.writeln('----------------------------------------------------------------');
  sb.writeln(
    '${l.poReportTotalInvoice}: ${metrics.totalAmount.toStringAsFixed(2)} $currency (${(metrics.totalAmount * exchangeRate).toStringAsFixed(2)} EGP)',
  );
  sb.writeln(
    '${l.poReportTotalPkgsAndPcs}: ${metrics.totalPackages.toStringAsFixed(0)} | ${l.poReportGrossWeight}: ${formatPOWeight(metrics.effectiveGrossWeight)} kg | ${l.poReportNetWeight}: ${formatPOWeight(metrics.totalNetWeight)} kg',
  );
  final palletText = metrics.totalPallets > 0 ? "${metrics.totalPallets} ${l.poReportPalletsCountUnit(metrics.totalPallets)}" : "None";
  sb.writeln(
    '${l.poReportVolumeCbm}: ${metrics.effectiveCbm.toStringAsFixed(3)} m³ | ${l.poReportPalletPlan}: $palletText',
  );
  sb.writeln('================================================================\n');

  sb.writeln('--- ${l.poReportSec1InvoiceItems} ---');
  sb.writeln('# | ${l.poReportColItemCode} | ${l.mainDescription} | ${l.poReportColDescription} | ${l.poReportColHsCode} | ${l.poReportColQtyUnit} | ${l.poReportColUnitPrice} | ${l.poReportColTotalAmount}');
  for (int i = 0; i < items.length; i++) {
    final it = items[i];
    final itemTot = it.totalPrice > 0 ? it.totalPrice : (it.quantity * it.unitPrice);
    final desc = isArabic ? it.descriptionAr : (it.descriptionEn?.isNotEmpty == true ? it.descriptionEn! : it.descriptionAr);
    final mainDesc = it.mainDescription?.isNotEmpty == true ? it.mainDescription! : "-";
    sb.writeln(
      '${i + 1} | ${it.itemCode ?? "-"} | $mainDesc | $desc | ${it.hsCode ?? "-"} | ${it.quantity} ${it.unitOfMeasure} | ${it.unitPrice.toStringAsFixed(2)} $currency | ${itemTot.toStringAsFixed(2)} $currency',
    );
  }

  sb.writeln('\n--- ${l.poReportSec2PackingList} ---');
  sb.writeln('# | ${l.poReportColItemCode} | ${l.mainDescription} | ${l.poReportColDescription} | ${l.poReportColPkgType} | ${l.poReportTotalPkgsAndPcs} | ${l.poReportColDimensions} | ${l.poReportGrossWeight} | ${l.poReportVolumeCbm}');
  for (int i = 0; i < packingItems.length; i++) {
    final p = packingItems[i];
    final dim = (p.lengthCm > 0 && p.widthCm > 0 && p.heightCm > 0)
        ? '${p.lengthCm}x${p.widthCm}x${p.heightCm}'
        : l.poReportDirectVolume;
    final grs = p.computedTotalGrossWeightKg;
    String mainDesc = p.mainDescription ?? '';
    if (mainDesc.isEmpty) {
      final matchedItem = items.where((it) => it.itemCode != null && it.itemCode == p.itemCode).firstOrNull;
      if (matchedItem != null && matchedItem.mainDescription?.isNotEmpty == true) {
        mainDesc = matchedItem.mainDescription!;
      }
    }
    sb.writeln(
      '${i + 1} | ${p.itemCode} | ${mainDesc.isNotEmpty ? mainDesc : "-"} | ${p.description ?? "-"} | ${p.packageType} | ${p.qtyPkg}/${p.qtyPcs} | $dim | ${formatPOWeight(grs)} kg | ${p.calculatedCbm.toStringAsFixed(3)} m³',
    );
  }

  if (palletItems.isNotEmpty) {
    sb.writeln('\n--- ${l.poReportSec3PalletPlan} ---');
    sb.writeln('# | ${l.palletTypeCol} | ${l.palletCountCol} | ${l.palletDimensionsCol} | ${l.palletWeightCol} | ${l.palletVolumeCol} | ${l.palletStackingInstructionsCol}');
    for (int i = 0; i < palletItems.length; i++) {
      final pal = palletItems[i];
      sb.writeln(
        '${i + 1} | ${pal.palletType} | ${pal.palletCount} | ${pal.lengthCm}x${pal.widthCm}x${pal.heightCm} | ${pal.totalWeightKg} kg | ${pal.calculatedCbm.toStringAsFixed(3)} m³ | ${pal.isStackable ? l.poReportStackableYes : l.poReportStackableNo}',
      );
    }
  }

  CopyHelper.copy(
    context,
    sb.toString(),
    customMessage: l.poReportCopiedToClipboard,
  );
}

/// Helper to trigger 3D container load simulation dialog.
void showPoVisualLoadPlanner({
  required BuildContext context,
  required String poNumber,
  required String companyName,
  required String supplierName,
  required List<PackingListItemModel> packingItems,
  required List<PalletPlanItemModel> palletItems,
  required bool isDirectVolumeMode,
}) {
  POVisualLoadPlannerDialog.show(
    context: context,
    poNumber: poNumber,
    companyName: companyName,
    supplierName: supplierName,
    packingItems: packingItems,
    palletItems: palletItems,
    isDirectVolumeMode: isDirectVolumeMode,
  );
}

/// Bottom footer action bar for PO preview dialog.
class POReportPreviewFooter extends StatelessWidget {
  final int itemsCount;
  final int packingItemsCount;
  final int totalPallets;
  final VoidCallback? onConfirmSave;

  const POReportPreviewFooter({
    super.key,
    required this.itemsCount,
    required this.packingItemsCount,
    required this.totalPallets,
    this.onConfirmSave,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        borderRadius: const BorderRadiusDirectional.only(
          bottomStart: Radius.circular(16),
          bottomEnd: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, color: AppTheme.emerald, size: 16),
              const SizedBox(width: 6),
              Text(
                '${l.poReportReadyForApproval}: ${l.poReportItemsCountUnit(itemsCount)} | ${l.poReportPackagesCountUnit(packingItemsCount)} ${totalPallets > 0 ? " | ${l.poReportPalletsCountUnit(totalPallets)}" : ""}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: l.poReportCloseAndEdit,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: l.poReportSaveAndApprove,
                icon: Icons.check_circle_outline,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: () {
                  Navigator.pop(context);
                  onConfirmSave?.call();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
