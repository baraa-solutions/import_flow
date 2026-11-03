import 'package:flutter/material.dart';
import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../purchase_orders/utils/po_packing_matcher.dart';
import '../../models/po_reconciliation_session_model.dart';
import '../../models/import_documentation_model.dart';

/// Helper service for copying to clipboard and exporting to Excel / PDF
/// for all tables in PO Reconciliation.
class PoReconciliationTableExporter {
  static String _formatWeight(double val) => PoPackingMatcher.formatWeight(val);

  static void copySessionsTable(
    BuildContext context,
    List<POReconciliationSessionModel> sessions,
    String Function(BuildContext, String) getLocalizedSessionStatus,
  ) {
    final l = context.l10n;
    final headers = [
      '#',
      l.poRecHistoryColSessionCode,
      l.poRecHistoryColImportFileImporter,
      l.poRecHistoryColInvoicePacking,
      l.poRecHistoryColTotalValue,
      l.poRecHistoryColPackagesWeight,
      l.poRecHistoryColCbm,
      l.poRecHistoryColStatus,
      l.poRecHistoryColSavedDate,
    ];
    final rows = sessions.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final sess = entry.value;
      final dateStr = (sess.createdAt != null && sess.createdAt!.length >= 10) ? sess.createdAt!.substring(0, 10) : '—';
      return [
        '$idx',
        sess.sessionCode,
        '${sess.importFileCode ?? ""} - ${sess.importerName ?? ""}',
        '${sess.finalInvoiceNumber ?? ""} | ${sess.finalPackingListNumber ?? ""}',
        '${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency}',
        '${sess.totalPackages.toStringAsFixed(0)} | ${_formatWeight(sess.totalGrossWeightKg)} kg',
        '${sess.totalCbm.toStringAsFixed(3)} m³',
        getLocalizedSessionStatus(context, sess.overallStatus),
        dateStr,
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }

  static Future<void> exportSessionsToExcel(
    BuildContext context,
    List<POReconciliationSessionModel> sessions,
    int? selectedImportFileId,
    String Function(BuildContext, String) getLocalizedSessionStatus,
  ) async {
    final headers = [
      '#',
      context.l10n.idocASessionCodeAlt,
      context.l10n.idocAImportFileImporter,
      context.l10n.idocAInvoicePackingList,
      context.l10n.idocATotalValue,
      context.l10n.idocAPackagesWeight,
      context.l10n.idocAVolumeCBM,
      context.l10n.status,
      context.l10n.idocASavedDate,
    ];
    final rows = sessions.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final sess = entry.value;
      final dateStr = (sess.createdAt != null && sess.createdAt!.length >= 10) ? sess.createdAt!.substring(0, 10) : '—';
      return [
        '$idx',
        sess.sessionCode,
        '${sess.importFileCode ?? ""} - ${sess.importerName ?? ""}',
        '${sess.finalInvoiceNumber ?? ""} | ${sess.finalPackingListNumber ?? ""}',
        '${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency}',
        '${sess.totalPackages.toStringAsFixed(0)} | ${_formatWeight(sess.totalGrossWeightKg)} kg',
        '${sess.totalCbm.toStringAsFixed(3)} m³',
        getLocalizedSessionStatus(context, sess.overallStatus),
        dateStr,
      ];
    }).toList();
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAPOReconciliationSessions,
      importFileNameOrCode: selectedImportFileId != null ? 'IMP-$selectedImportFileId' : 'PO_Reconciliations',
    );
  }

  static Future<void> exportSessionsToPdf(
    BuildContext context,
    List<POReconciliationSessionModel> sessions,
    int? selectedImportFileId,
    String Function(BuildContext, String) getLocalizedSessionStatus,
  ) async {
    final headers = [
      '#',
      context.l10n.idocACodeAlt,
      context.l10n.idocAFileAlt,
      context.l10n.idocAInvoice,
      context.l10n.idocAValue,
      context.l10n.idocAPackages,
      context.l10n.status,
    ];
    final rows = sessions.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final sess = entry.value;
      return [
        '$idx',
        sess.sessionCode,
        sess.importFileCode ?? '-',
        sess.finalInvoiceNumber ?? '-',
        '${sess.totalInvoiceAmount.toStringAsFixed(0)} ${sess.currency}',
        sess.totalPackages.toStringAsFixed(0),
        getLocalizedSessionStatus(context, sess.overallStatus),
      ];
    }).toList();
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAPOReconciliationSessionsAlt,
      importFileNameOrCode: selectedImportFileId != null ? 'IMP-$selectedImportFileId' : 'PO_Reconciliations',
    );
  }

  static void copyInvoiceItemsTable(
    BuildContext context,
    List<POReconciliationItemModel> invoiceItems,
  ) {
    final l = context.l10n;
    final headers = [
      l.poRecColItemCode,
      l.poRecColDescription,
      l.poRecColPoQty,
      l.poRecColFinalQty,
      l.poRecColQtyVariance,
      l.poRecColPoUnitPrice,
      l.poRecColFinalUnitPrice,
      l.poRecColPriceVariance,
      l.poRecColFinalTotal,
      l.poRecColHsCode,
    ];
    final rows = invoiceItems.map((itm) {
      final qtyVariance = itm.finalQuantity - itm.initialQuantity;
      final priceVariance = itm.finalUnitPrice - itm.initialUnitPrice;
      final totalRow = itm.finalQuantity * (itm.finalUnitPrice > 0 ? itm.finalUnitPrice : itm.unitPrice);
      return [
        itm.itemCode,
        itm.description,
        '${itm.initialQuantity}',
        '${itm.finalQuantity}',
        '$qtyVariance',
        '${itm.initialUnitPrice}',
        '${itm.finalUnitPrice}',
        '$priceVariance',
        totalRow.toStringAsFixed(2),
        itm.hsCode ?? '',
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }

  static Future<void> exportInvoiceItemsToExcel(
    BuildContext context,
    List<POReconciliationItemModel> invoiceItems,
    int? selectedImportFileId,
  ) async {
    final headers = [
      context.l10n.idocAItemCode,
      context.l10n.idocADescription,
      context.l10n.idocAPOQty,
      context.l10n.idocAFinalQty,
      context.l10n.idocAQtyVariance,
      context.l10n.idocAPOUnitPrice,
      context.l10n.idocAFinalUnitPrice,
      context.l10n.idocAPriceVariance,
      context.l10n.idocAFinalTotal,
      context.l10n.idocAHSCode,
    ];
    final rows = invoiceItems.map((itm) {
      final qtyVariance = itm.finalQuantity - itm.initialQuantity;
      final priceVariance = itm.finalUnitPrice - itm.initialUnitPrice;
      final totalRow = itm.finalQuantity * (itm.finalUnitPrice > 0 ? itm.finalUnitPrice : itm.unitPrice);
      return [
        itm.itemCode,
        itm.description,
        '${itm.initialQuantity}',
        '${itm.finalQuantity}',
        '$qtyVariance',
        '${itm.initialUnitPrice}',
        '${itm.finalUnitPrice}',
        '$priceVariance',
        totalRow.toStringAsFixed(2),
        itm.hsCode ?? '',
      ];
    }).toList();
    if (invoiceItems.isNotEmpty) {
      final totalPoQty = invoiceItems.fold(0.0, (s, i) => s + i.initialQuantity);
      final totalFinQty = invoiceItems.fold(0.0, (s, i) => s + i.finalQuantity);
      final totalPoAmt = invoiceItems.fold(0.0, (s, i) => s + (i.initialQuantity * i.initialUnitPrice));
      final totalFinAmt = invoiceItems.fold(
        0.0,
        (s, i) => s + (i.finalQuantity * (i.finalUnitPrice > 0 ? i.finalUnitPrice : i.unitPrice)),
      );
      rows.add([
        context.l10n.idocATotal,
        '${invoiceItems.length} items',
        '$totalPoQty',
        '$totalFinQty',
        '${totalFinQty - totalPoQty}',
        totalPoAmt.toStringAsFixed(2),
        '—',
        '${totalFinAmt - totalPoAmt}',
        totalFinAmt.toStringAsFixed(2),
        '',
      ]);
    }
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAInvoiceItemsReconciliation,
      importFileNameOrCode: selectedImportFileId != null ? 'IMP-$selectedImportFileId' : 'Invoice_Items',
    );
  }

  static Future<void> exportInvoiceItemsToPdf(
    BuildContext context,
    List<POReconciliationItemModel> invoiceItems,
    int? selectedImportFileId,
  ) async {
    final headers = [
      context.l10n.idocACode,
      context.l10n.idocADescription,
      context.l10n.idocAPOQtyAlt,
      context.l10n.idocAFinalQtyAlt,
      context.l10n.idocAUnitPrice,
      context.l10n.idocATotalAlt,
    ];
    final rows = invoiceItems.map((itm) {
      final totalRow = itm.finalQuantity * (itm.finalUnitPrice > 0 ? itm.finalUnitPrice : itm.unitPrice);
      return [
        itm.itemCode,
        itm.description,
        '${itm.initialQuantity}',
        '${itm.finalQuantity}',
        '${itm.finalUnitPrice > 0 ? itm.finalUnitPrice : itm.unitPrice}',
        totalRow.toStringAsFixed(2),
      ];
    }).toList();
    if (invoiceItems.isNotEmpty) {
      final totalPoQty = invoiceItems.fold(0.0, (s, i) => s + i.initialQuantity);
      final totalFinQty = invoiceItems.fold(0.0, (s, i) => s + i.finalQuantity);
      final totalFinAmt = invoiceItems.fold(
        0.0,
        (s, i) => s + (i.finalQuantity * (i.finalUnitPrice > 0 ? i.finalUnitPrice : i.unitPrice)),
      );
      rows.add([
        context.l10n.idocATotalAlt,
        '${invoiceItems.length} items',
        '$totalPoQty',
        '$totalFinQty',
        '—',
        totalFinAmt.toStringAsFixed(2),
      ]);
    }
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAInvoiceItems,
      importFileNameOrCode: selectedImportFileId != null ? 'IMP-$selectedImportFileId' : 'Invoice_Items',
    );
  }

  static void copyPackingItemsTable(
    BuildContext context,
    List<POReconciliationItemModel> packingItems,
  ) {
    final l = context.l10n;
    final headers = [
      l.poRecColItemCode,
      l.poRecColDescription,
      l.poRecColPackageType,
      l.poRecColPoPackagesCount,
      l.poRecColFinalPackagesCount,
      l.poRecColPkgVariance,
      l.poRecColGrossWeight,
      l.poRecColNetWeight,
      l.poRecColCbm,
    ];
    final rows = packingItems.map((itm) {
      final double initP = itm.initialPackagesCount;
      final double finP = itm.finalPackagesCount;
      final double varPct = initP > 0 ? ((finP - initP) / initP) * 100.0 : 0.0;
      return [
        itm.itemCode,
        itm.description,
        itm.packageType,
        '${initP.toInt() == initP ? initP.toInt() : initP}',
        '${finP.toInt() == finP ? finP.toInt() : finP}',
        '${varPct.toStringAsFixed(1)}%',
        '${itm.finalGrossWeightKg}',
        '${itm.finalNetWeightKg}',
        '${itm.finalCbm}',
      ];
    }).toList();
    TableCopyHelper.copyTable(context, headers, rows);
  }

  static Future<void> exportPackingItemsToExcel(
    BuildContext context,
    List<POReconciliationItemModel> packingItems,
    int? selectedImportFileId,
  ) async {
    final headers = [
      context.l10n.idocAItemCode,
      context.l10n.idocADescription,
      context.l10n.idocAPackageType,
      context.l10n.idocAPOPackages,
      context.l10n.idocAFinalPackages,
      context.l10n.idocAPackagesVariance,
      context.l10n.idocAGrossWeightKg,
      context.l10n.idocANetWeightKg,
      context.l10n.idocACBM,
    ];
    final rows = packingItems.map((itm) {
      final double initP = itm.initialPackagesCount;
      final double finP = itm.finalPackagesCount;
      final double varPct = initP > 0 ? ((finP - initP) / initP) * 100.0 : 0.0;
      return [
        itm.itemCode,
        itm.description,
        itm.packageType,
        '${initP.toInt() == initP ? initP.toInt() : initP}',
        '${finP.toInt() == finP ? finP.toInt() : finP}',
        '${varPct.toStringAsFixed(1)}%',
        '${itm.finalGrossWeightKg}',
        '${itm.finalNetWeightKg}',
        '${itm.finalCbm}',
      ];
    }).toList();
    if (packingItems.isNotEmpty) {
      final totalPoPkgs = packingItems.fold(0.0, (s, i) => s + i.initialPackagesCount);
      final totalPkgs = packingItems.fold(0.0, (s, i) => s + i.finalPackagesCount);
      final totalGross = packingItems.fold(0.0, (s, i) => s + i.finalGrossWeightKg);
      final totalNet = packingItems.fold(0.0, (s, i) => s + i.finalNetWeightKg);
      final totalCbm = packingItems.fold(0.0, (s, i) => s + i.finalCbm);
      final overallVar = totalPoPkgs > 0 ? ((totalPkgs - totalPoPkgs) / totalPoPkgs) * 100.0 : 0.0;
      rows.add([
        context.l10n.idocATotal,
        '${packingItems.length} items',
        '—',
        '${totalPoPkgs.toInt() == totalPoPkgs ? totalPoPkgs.toInt() : totalPoPkgs}',
        '${totalPkgs.toInt() == totalPkgs ? totalPkgs.toInt() : totalPkgs}',
        '${overallVar.toStringAsFixed(1)}%',
        _formatWeight(totalGross),
        _formatWeight(totalNet),
        totalCbm.toStringAsFixed(3),
      ]);
    }
    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAPackingListReconciliation,
      importFileNameOrCode: selectedImportFileId != null ? 'IMP-$selectedImportFileId' : 'Packing_Items',
    );
  }

  static Future<void> exportPackingItemsToPdf(
    BuildContext context,
    List<POReconciliationItemModel> packingItems,
    int? selectedImportFileId,
  ) async {
    final headers = [
      context.l10n.idocACode,
      context.l10n.idocADescription,
      context.l10n.idocAPOPkgs,
      context.l10n.idocAFinalPkgs,
      context.l10n.idocAVariance,
      context.l10n.idocAGrossWt,
      context.l10n.idocANetWt,
      context.l10n.idocACBMAlt,
    ];
    final rows = packingItems.map((itm) {
      final double initP = itm.initialPackagesCount;
      final double finP = itm.finalPackagesCount;
      final double varPct = initP > 0 ? ((finP - initP) / initP) * 100.0 : 0.0;
      return [
        itm.itemCode,
        itm.description,
        '${initP.toInt() == initP ? initP.toInt() : initP}',
        '${finP.toInt() == finP ? finP.toInt() : finP}',
        '${varPct.toStringAsFixed(1)}%',
        '${_formatWeight(itm.finalGrossWeightKg)} kg',
        '${_formatWeight(itm.finalNetWeightKg)} kg',
        '${itm.finalCbm} m³',
      ];
    }).toList();
    if (packingItems.isNotEmpty) {
      final totalPoPkgs = packingItems.fold(0.0, (s, i) => s + i.initialPackagesCount);
      final totalPkgs = packingItems.fold(0.0, (s, i) => s + i.finalPackagesCount);
      final totalGross = packingItems.fold(0.0, (s, i) => s + i.finalGrossWeightKg);
      final totalNet = packingItems.fold(0.0, (s, i) => s + i.finalNetWeightKg);
      final totalCbm = packingItems.fold(0.0, (s, i) => s + i.finalCbm);
      final overallVar = totalPoPkgs > 0 ? ((totalPkgs - totalPoPkgs) / totalPoPkgs) * 100.0 : 0.0;
      rows.add([
        context.l10n.idocATotalAlt,
        '${packingItems.length} items',
        '${totalPoPkgs.toInt() == totalPoPkgs ? totalPoPkgs.toInt() : totalPoPkgs}',
        '${totalPkgs.toInt() == totalPkgs ? totalPkgs.toInt() : totalPkgs}',
        '${overallVar.toStringAsFixed(1)}%',
        '${_formatWeight(totalGross)} kg',
        '${_formatWeight(totalNet)} kg',
        '${totalCbm.toStringAsFixed(3)} m³',
      ]);
    }
    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAPackingListItems,
      importFileNameOrCode: selectedImportFileId != null ? 'IMP-$selectedImportFileId' : 'Packing_Items',
    );
  }
}
