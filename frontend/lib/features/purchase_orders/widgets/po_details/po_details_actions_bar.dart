import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/purchase_order_model.dart';
import '../../utils/po_packing_matcher.dart';
import 'po_resolved_metrics.dart';

/// Bottom action buttons toolbar for Purchase Order Details Dialog.
///
/// Provides:
/// - 3D Simulation shortcut button
/// - Export to Excel via [TableExportService] (FileSaveHelper)
/// - Export to PDF via [TableExportService] (FileSaveHelper)
/// - Copy all PO proforma & packing details via [CopyHelper]
/// - Edit purchase order action
/// - Close dialog button
class PoDetailsActionsBar extends StatelessWidget {
  final PurchaseOrderModel po;
  final POResolvedMetrics metrics;
  final VoidCallback? onEdit;
  final VoidCallback? onOpen3dPlanner;

  const PoDetailsActionsBar({
    super.key,
    required this.po,
    required this.metrics,
    this.onEdit,
    this.onOpen3dPlanner,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Wrap(
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
          label: l.originalDocsExportExcelBtn,
          icon: Icons.table_chart,
          variant: AppButtonVariant.success,
          onPressed: () => _exportPoToExcel(context, isArabic),
        ),
        AppButton(
          label: l.exportPdf,
          icon: Icons.picture_as_pdf,
          variant: AppButtonVariant.danger,
          onPressed: () => _exportPoToPdf(context, isArabic),
        ),
        AppButton(
          label: l.copyAllData,
          icon: Icons.copy_all,
          variant: AppButtonVariant.secondary,
          onPressed: () => _copyPoDetailsToClipboard(context, isArabic),
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
    );
  }

  void _copyPoDetailsToClipboard(BuildContext context, bool isArabic) {
    final l = context.l10n;
    final buffer = StringBuffer();
    buffer.writeln(l.poPurchaseOrderProformaInvoiceDetails);
    buffer.writeln('${l.poPOReferenceName}: ${po.displayName}');
    if (po.displayName != po.poNumber) {
      buffer.writeln('${l.poInternalPOCode}: ${po.poNumber}');
    }
    if (po.proformaInvoiceNumber != null && po.proformaInvoiceNumber!.isNotEmpty) {
      buffer.writeln('${l.poProformaInvoice}: ${po.proformaInvoiceNumber}');
    }
    if (po.projectName != null && po.projectName!.isNotEmpty) {
      buffer.writeln('${l.poProjectCostCenter}: ${po.projectName}');
    }
    if (po.companyName != null && po.companyName!.isNotEmpty) {
      buffer.writeln('${l.operationalTsvHeaderImporter}: ${po.companyName}');
    }
    if (po.supplierName != null && po.supplierName!.isNotEmpty) {
      buffer.writeln('${l.operationalTsvHeaderSupplier}: ${po.supplierName}');
    }
    if (po.countryOfOrigin != null && po.countryOfOrigin!.isNotEmpty) {
      buffer.writeln('${l.countryOfOriginCol}: ${po.countryOfOrigin}');
    }
    if (po.incotermCode != null && po.incotermCode!.isNotEmpty) {
      buffer.writeln('${l.poIncoterms}: ${po.incotermCode}');
    }
    buffer.writeln('${l.currency}: ${po.currencyCode ?? "USD"} (${l.poFXRate}: ${po.exchangeRate})');
    if (po.paymentTerms != null && po.paymentTerms!.isNotEmpty) {
      buffer.writeln('${l.poPaymentTerms}: ${po.paymentTerms}');
    }
    buffer.writeln('${l.smartExtractorFieldTotalAmount}: ${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}');
    buffer.writeln('${l.poTotalCBM}: ${po.totalCbm.toStringAsFixed(3)} m³');
    buffer.writeln('${l.poGrossNetWeight}: ${po.totalGrossWeightKg.toStringAsFixed(1)} kg / ${po.totalNetWeightKg.toStringAsFixed(1)} kg');
    buffer.writeln('${l.smartExtractorFieldPackagesCount}: ${po.totalPackagesCount} ${po.packingListItems.isNotEmpty ? po.packingListItems.first.packageType : "Carton"}');
    buffer.writeln('${l.drillDownLabelStatus}: ${po.statusLabel(l)}');
    if (po.notes != null && po.notes!.isNotEmpty) {
      buffer.writeln('${l.customsClearanceColNotes}: ${po.notes}');
    }
    buffer.writeln();

    buffer.writeln(l.poPOLineItemsHSCodes);
    buffer.writeln('Item Code\tMain Description\tDescription & HS Code\tQty / UOM\tUnit Price\tLine Total\tVolume CBM');
    for (final item in po.items) {
      buffer.writeln(
        '${item.itemCode ?? "-"}\t${item.mainDescription ?? "-"}\t${item.descriptionAr} (HS: ${item.hsCode ?? "-"})\t${item.quantity} ${item.unitOfMeasure}\t${po.currencyCode ?? "USD"} ${item.unitPrice.toStringAsFixed(2)}\t${po.currencyCode ?? "USD"} ${item.totalPrice.toStringAsFixed(2)}\t${item.totalCbm.toStringAsFixed(3)}',
      );
    }

    if (po.packingListItems.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(l.poPackingListItems);
      buffer.writeln('HS Code\tItem Code\tDescription\tPackages\tPackage Type\tDimensions (cm)\tNet Weight (kg)\tGross Weight (kg)\tCBM');
      for (final pl in po.packingListItems) {
        final dims = pl.lengthCm > 0 ? '${pl.lengthCm}x${pl.widthCm}x${pl.heightCm}' : '-';
        final netWt = POResolvedMetrics.formatWeight((pl.netWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.qtyPkg * pl.netWeightUnitKg) : pl.totalNetWeightKg);
        final grossWt = POResolvedMetrics.formatWeight((pl.grossWeightUnitKg > 0 && pl.qtyPkg > 0) ? (pl.qtyPkg * pl.grossWeightUnitKg) : pl.totalGrossWeightKg);
        final cbm = (pl.calculatedCbm > 0 ? pl.calculatedCbm : pl.totalCbm).toStringAsFixed(3);
        buffer.writeln(
          '${pl.hsCode}\t${pl.itemCode}\t${pl.description ?? pl.mainDescription ?? "-"}\t${pl.qtyPkg}\t${pl.packageType}\t$dims\t$netWt\t$grossWt\t$cbm',
        );
      }
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l.poPODetailsCopiedToClipboard,
    );
  }

  Future<void> _exportPoToExcel(BuildContext context, bool isArabic) async {
    final l = context.l10n;

    final headers = [
      l.gitColItemCode,
      l.poRecColDescription,
      l.requirementsTsvHeaderHsCode,
      l.financialSettlementColQty,
      l.unitCol,
      l.poQtyPKG,
      l.poPackageType,
      l.smartExtractorColUnitPrice,
      l.freightDataTotalLabel,
      l.poNetWtKg,
      l.poGrossWtKg,
      l.poCBM,
    ];

    final rows = metrics.resolvedPoItems.map((resolved) {
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
        POResolvedMetrics.formatWeight(resolved.netWeightKg),
        POResolvedMetrics.formatWeight(resolved.grossWeightKg),
        resolved.cbm.toStringAsFixed(3),
      ];
    }).toList();

    // Section 1: PO Line Items Summary By HS Code
    final poHsHeaders = [
      l.requirementsTsvHeaderHsCode,
      l.financialSettlementColQty,
      l.poQtyPKG,
      l.poNetWtKg,
      l.poGrossWtKg,
      l.freightBookingCbmVolumeLabel,
      l.smartExtractorFieldTotalAmount,
      l.poDutyVAT,
    ];

    final poHsRows = metrics.poHsSummaryMap.values.map((s) {
      return [
        '${s['hs_code']}',
        '${s['qty']}',
        '${s['qty_pkg']}',
        POResolvedMetrics.formatWeight(s['total_net'] as double),
        POResolvedMetrics.formatWeight(s['total_gross'] as double),
        (s['total_cbm'] as double).toStringAsFixed(3),
        '${po.currencyCode ?? "USD"} ${(s['total_price'] as double).toStringAsFixed(2)}',
        '${s['duty_rate']}% / ${s['vat_rate']}%',
      ];
    }).toList();

    final List<TableExportSection> additionalSections = [
      TableExportSection(
        title: l.poPOLineItemsSummaryByHS,
        headers: poHsHeaders,
        rows: poHsRows,
      ),
    ];

    // Section 2: Packing List Summary By HS Code (if packing list exists)
    if (po.packingListItems.isNotEmpty) {
      final plHsHeaders = [
        l.requirementsTsvHeaderHsCode,
        l.poQtyPcs,
        l.poQtyPKG,
        l.poNetWtKg,
        l.poGrossWtKg,
        l.freightBookingCbmVolumeLabel,
      ];

      final plHsRows = metrics.hsSummaryMap.values.map((s) {
        return [
          '${s['hs_code']}',
          '${s['qty_pcs']}',
          '${s['qty_pkg']}',
          POResolvedMetrics.formatWeight(s['total_net'] as double),
          POResolvedMetrics.formatWeight(s['total_gross'] as double),
          (s['total_cbm'] as double).toStringAsFixed(3),
        ];
      }).toList();

      additionalSections.add(
        TableExportSection(
          title: l.poPackingListSummaryByHSCode,
          headers: plHsHeaders,
          rows: plHsRows,
        ),
      );
    }

    // Section 3: Packing List Summary By Package Type (if packing list exists)
    if (metrics.packageTypeSummaryMap.isNotEmpty) {
      final pkgHeaders = [
        l.poPackageType,
        l.poRecReportPackages,
        l.poNetWtKg,
        l.poGrossWtKg,
        l.freightBookingCbmVolumeLabel,
      ];

      final pkgRows = metrics.packageTypeSummaryMap.values.map((s) {
        final double qty = (s['qty_pkg'] as num).toDouble();
        final String qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
        return [
          '${s['package_type']}',
          qtyStr,
          POResolvedMetrics.formatWeight(s['total_net'] as double),
          POResolvedMetrics.formatWeight(s['total_gross'] as double),
          (s['total_cbm'] as double).toStringAsFixed(3),
        ];
      }).toList();

      additionalSections.add(
        TableExportSection(
          title: l.poPackingListSummaryByPackageType,
          headers: pkgHeaders,
          rows: pkgRows,
        ),
      );
    }

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.poPurchaseOrder,
      importFileNameOrCode: po.displayName,
      additionalSections: additionalSections,
    );
  }

  Future<void> _exportPoToPdf(BuildContext context, bool isArabic) async {
    final l = context.l10n;

    final headers = [
      l.gitColItemCode,
      l.poRecColDescription,
      l.requirementsTsvHeaderHsCode,
      l.financialSettlementColQty,
      l.unitCol,
      l.poQtyPKG,
      l.poPackageType,
      l.smartExtractorColUnitPrice,
      l.freightDataTotalLabel,
      l.poNetWtKg,
      l.poGrossWtKg,
      l.poCBM,
    ];

    final rows = metrics.resolvedPoItems.map((resolved) {
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
        POResolvedMetrics.formatWeight(resolved.netWeightKg),
        POResolvedMetrics.formatWeight(resolved.grossWeightKg),
        resolved.cbm.toStringAsFixed(3),
      ];
    }).toList();

    final totalPkgSummary = PoPackingMatcher.formatPackagingSummary(
      packingListItems: po.packingListItems,
      totalPalletCount: metrics.totalPalletCount,
      isArabic: isArabic,
    );

    final metadata = <String, String>{
      l.poPOReferenceName: po.displayName,
      if (po.displayName != po.poNumber)
        l.poInternalPOCode2: po.poNumber,
      if (po.proformaInvoiceNumber != null && po.proformaInvoiceNumber!.isNotEmpty)
        l.customsApprovalDocProformaInvoice: po.proformaInvoiceNumber!,
      if (po.companyName != null && po.companyName!.isNotEmpty)
        l.operationalTsvHeaderImporter: po.companyName!,
      if (po.supplierName != null && po.supplierName!.isNotEmpty)
        l.draftBlPartySupplier: po.supplierName!,
      if (po.incotermCode != null && po.incotermCode!.isNotEmpty)
        l.poIncoterms: po.incotermCode!,
      l.smartExtractorFieldTotalAmount: '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}',
      l.poTotalCBM2: '${metrics.effectivePackingListCbm.toStringAsFixed(3)} m³${metrics.totalPalletCount > 0 ? " (${metrics.totalPalletCount} Pallets)" : ""}',
      l.smartExtractorFieldTotalGrossWeight: '${POResolvedMetrics.formatWeight(metrics.effectivePackingListGrossWeight)} kg',
      l.poTotalNetWeight: '${POResolvedMetrics.formatWeight(metrics.effectivePackingListNetWeight)} kg',
      l.poTotalQtyPKG2: totalPkgSummary,
    };

    final poHsHeaders = [
      l.requirementsTsvHeaderHsCode,
      l.financialSettlementColQty,
      l.poQtyPKG,
      l.poNetWtKg,
      l.poGrossWtKg,
      l.freightBookingCbmVolumeLabel,
      l.smartExtractorFieldTotalAmount,
      l.poDutyVAT,
    ];

    final poHsRows = metrics.poHsSummaryMap.values.map((s) {
      return [
        '${s['hs_code']}',
        '${s['qty']}',
        '${s['qty_pkg']}',
        POResolvedMetrics.formatWeight(s['total_net'] as double),
        POResolvedMetrics.formatWeight(s['total_gross'] as double),
        (s['total_cbm'] as double).toStringAsFixed(3),
        '${po.currencyCode ?? "USD"} ${(s['total_price'] as double).toStringAsFixed(2)}',
        '${s['duty_rate']}% / ${s['vat_rate']}%',
      ];
    }).toList();

    final List<TableExportSection> additionalSections = [
      TableExportSection(
        title: l.poPOLineItemsSummaryByHS,
        headers: poHsHeaders,
        rows: poHsRows,
      ),
    ];

    if (po.packingListItems.isNotEmpty) {
      final plHsHeaders = [
        l.requirementsTsvHeaderHsCode,
        l.poQtyPcs,
        l.poQtyPKG,
        l.poNetWtKg,
        l.poGrossWtKg,
        l.freightBookingCbmVolumeLabel,
      ];

      final plHsRows = metrics.hsSummaryMap.values.map((s) {
        return [
          '${s['hs_code']}',
          '${s['qty_pcs']}',
          '${s['qty_pkg']}',
          POResolvedMetrics.formatWeight(s['total_net'] as double),
          POResolvedMetrics.formatWeight(s['total_gross'] as double),
          (s['total_cbm'] as double).toStringAsFixed(3),
        ];
      }).toList();

      additionalSections.add(
        TableExportSection(
          title: l.poPackingListSummaryByHSCode,
          headers: plHsHeaders,
          rows: plHsRows,
        ),
      );
    }

    if (metrics.packageTypeSummaryMap.isNotEmpty) {
      final pkgHeaders = [
        l.poPackageType,
        l.poRecReportPackages,
        l.poNetWtKg,
        l.poGrossWtKg,
        l.freightBookingCbmVolumeLabel,
      ];

      final pkgRows = metrics.packageTypeSummaryMap.values.map((s) {
        final double qty = (s['qty_pkg'] as num).toDouble();
        final String qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
        return [
          '${s['package_type']}',
          qtyStr,
          POResolvedMetrics.formatWeight(s['total_net'] as double),
          POResolvedMetrics.formatWeight(s['total_gross'] as double),
          (s['total_cbm'] as double).toStringAsFixed(3),
        ];
      }).toList();

      additionalSections.add(
        TableExportSection(
          title: l.poPackingListSummaryByPackageType,
          headers: pkgHeaders,
          rows: pkgRows,
        ),
      );
    }

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.poPurchaseOrder,
      importFileNameOrCode: po.displayName,
      additionalSections: additionalSections,
      headerContext: TableExportHeaderContext(
        title: l.poPurchaseOrderItemsSpecification,
        subtitle: 'Sorour Logistics ERP — ${po.displayName}',
        metadata: metadata,
      ),
    );
  }
}
