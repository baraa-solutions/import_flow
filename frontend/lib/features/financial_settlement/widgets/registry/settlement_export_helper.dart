import 'package:flutter/material.dart';
import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/financial_settlement_model.dart';
import '../settlement_registry_card.dart';

class SettlementExportHelper {
  static String fileTitle(LandedCostSettlementModel r, Map<int, dynamic> importFilesMap) {
    final matchingFile = importFilesMap[r.importFileId];
    final fileCode = matchingFile?.primaryNameWithCode ?? 'IMP-${r.importFileId}';
    final compName = matchingFile?.companyName ?? '';
    return compName.isNotEmpty ? '$fileCode - $compName' : fileCode;
  }

  static String statusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'Calculated':
        return l10n.financialSettlementStatusCalculated;
      case 'Approved':
        return l10n.financialSettlementStatusApproved;
      case 'Draft':
        return l10n.financialSettlementStatusDraft;
      default:
        return status;
    }
  }

  static List<String> registryHeaders(AppLocalizations l10n, {required bool withCurrency}) {
    final c = withCurrency ? ' (${l10n.financialSettlementCurrencyEgp})' : '';
    return [
      l10n.settlementExpColCode,
      l10n.settlementExpColFile,
      l10n.settlementExpColAccountant,
      l10n.settlementExpColStatus,
      '${l10n.settlementExpColFob}$c',
      '${l10n.settlementExpColExpenses}$c',
      '${l10n.settlementExpColLanded}$c',
      l10n.settlementExpColMarkup,
    ];
  }

  static void copySettlementRowTsv(
    BuildContext context,
    LandedCostSettlementModel r,
    AppLocalizations l10n,
    Map<int, dynamic> importFilesMap,
  ) {
    final values = [
      r.settlementCode,
      fileTitle(r, importFilesMap),
      r.accountantName,
      statusLabel(l10n, r.status),
      r.totalFobEgp.toStringAsFixed(2),
      r.totalExpensesEgp.toStringAsFixed(2),
      r.totalLandedCostEgp.toStringAsFixed(2),
      '${r.averageMarkupFactor.toStringAsFixed(3)}x',
    ];

    TableCopyHelper.copyRow(
      context,
      values,
      headers: registryHeaders(l10n, withCurrency: true),
      customMessage: l10n.copyFinancialSettlementRowSuccess,
    );
  }

  static Future<void> exportSettlementsExcel(
    BuildContext context,
    List<LandedCostSettlementModel> records,
    AppLocalizations l10n,
    Map<int, dynamic> importFilesMap,
  ) async {
    final rows = records
        .map((r) => [
              r.settlementCode,
              fileTitle(r, importFilesMap),
              r.accountantName,
              statusLabel(l10n, r.status),
              r.totalFobEgp.toStringAsFixed(2),
              r.totalExpensesEgp.toStringAsFixed(2),
              r.totalLandedCostEgp.toStringAsFixed(2),
              '${r.averageMarkupFactor.toStringAsFixed(3)}x',
            ])
        .toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Financial Settlement',
      importFileNameOrCode: 'Registry',
      headers: registryHeaders(l10n, withCurrency: true),
      rows: rows,
    );
  }

  static Future<void> exportSettlementsPdf(
    BuildContext context,
    List<LandedCostSettlementModel> records,
    AppLocalizations l10n,
    Map<int, dynamic> importFilesMap,
  ) async {
    final currencyStr = l10n.financialSettlementCurrencyEgp;
    final rows = records
        .map((r) => [
              r.settlementCode,
              fileTitle(r, importFilesMap),
              r.accountantName,
              statusLabel(l10n, r.status),
              '${r.totalFobEgp.toStringAsFixed(2)} $currencyStr',
              '${r.totalExpensesEgp.toStringAsFixed(2)} $currencyStr',
              '${r.totalLandedCostEgp.toStringAsFixed(2)} $currencyStr',
              '${r.averageMarkupFactor.toStringAsFixed(3)}x',
            ])
        .toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'Financial Settlement',
      importFileNameOrCode: 'Registry',
      headers: registryHeaders(l10n, withCurrency: false),
      rows: rows,
      headerContext: TableExportHeaderContext(
        title: l10n.settlementPdfTitle,
        subtitle: l10n.settlementPdfSubtitle,
        metadata: {
          l10n.settlementPdfMetaTotal: records.length.toString(),
          l10n.financialSettlementStatusCalculated:
              records.where((r) => r.status == 'Calculated').length.toString(),
          l10n.financialSettlementStatusApproved:
              records.where((r) => r.status == 'Approved').length.toString(),
        },
      ),
    );
  }

  static void copySettlementRecordsTsv(
    BuildContext context,
    List<LandedCostSettlementModel> records,
    Map<int, dynamic> importFilesMap,
  ) {
    final l10n = context.l10n;
    final buffer = StringBuffer();
    buffer.writeln(registryHeaders(l10n, withCurrency: true).join('\t'));

    for (final r in records) {
      buffer.writeln([
        r.settlementCode,
        fileTitle(r, importFilesMap),
        r.accountantName,
        statusLabel(l10n, r.status),
        r.totalFobEgp.toStringAsFixed(2),
        r.totalExpensesEgp.toStringAsFixed(2),
        r.totalLandedCostEgp.toStringAsFixed(2),
        '${r.averageMarkupFactor.toStringAsFixed(3)}x',
      ].join('\t'));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.financialSettlementExportTsvSuccess,
    );
  }

  static void copySettlementBreakdownTsv(
    BuildContext context,
    LandedCostSettlementModel record,
    Map<int, dynamic> importFilesMap,
  ) {
    final l10n = context.l10n;
    final currencyStr = l10n.financialSettlementCurrencyEgp;
    final buffer = StringBuffer();
    final fTitle = fileTitle(record, importFilesMap);

    buffer.writeln(l10n.settlementBreakdownTitle(record.settlementCode));
    buffer.writeln('${l10n.settlementExpColFile}:\t$fTitle\t${l10n.settlementExpColAccountant}:\t${record.accountantName}');
    buffer.writeln('${l10n.settlementExpColFob}:\t${record.totalFobEgp.toStringAsFixed(2)} $currencyStr\t${l10n.settlementExpColExpenses}:\t${record.totalExpensesEgp.toStringAsFixed(2)} $currencyStr');
    buffer.writeln('${l10n.settlementExpColLanded}:\t${record.totalLandedCostEgp.toStringAsFixed(2)} $currencyStr\t${l10n.settlementExpColMarkup}:\t${record.averageMarkupFactor.toStringAsFixed(3)}x');
    buffer.writeln('');
    buffer.writeln('=== ${l10n.settlementBreakdownExpensesSection} ===');
    buffer.writeln([
      l10n.financialSettlementColInvoiceNo,
      l10n.financialSettlementColCategory,
      l10n.financialSettlementColProvider,
      l10n.financialSettlementColAmountFx,
      l10n.financialSettlementColExchangeRate,
      l10n.financialSettlementColAmountEgp,
      l10n.financialSettlementColAllocationRule,
    ].join('\t'));

    for (final exp in record.expenseInvoices) {
      buffer.writeln([
        exp.invoiceNo,
        settlementCategoryLabel(context, exp.category),
        exp.providerName,
        '${exp.amountFx.toStringAsFixed(2)} ${exp.currency}',
        '${exp.exchangeRate}',
        '${exp.amountEgp.toStringAsFixed(2)} $currencyStr',
        settlementRuleLabel(context, exp.allocationRule),
      ].join('\t'));
    }

    buffer.writeln('');
    buffer.writeln('=== ${l10n.settlementBreakdownItemsSection} ===');
    buffer.writeln([
      l10n.financialSettlementColItemCode,
      l10n.financialSettlementColItemName,
      l10n.financialSettlementColQty,
      l10n.financialSettlementColFobUnit,
      l10n.financialSettlementColAllocatedFreight,
      l10n.financialSettlementColAllocatedCustoms,
      l10n.financialSettlementColAllocatedClearance,
      l10n.financialSettlementColAllocatedTransport,
      l10n.financialSettlementColUnitLandedCost,
      l10n.financialSettlementColMarkupFactor,
    ].join('\t'));

    for (final itm in record.itemLandedCosts) {
      buffer.writeln([
        itm.itemCode,
        itm.itemName,
        itm.qtyLabel,
        '${itm.fobUnitEgp.toStringAsFixed(2)} $currencyStr',
        '${itm.allocatedFreightEgp.toStringAsFixed(2)} $currencyStr',
        '${itm.allocatedCustomsEgp.toStringAsFixed(2)} $currencyStr',
        '${itm.allocatedClearanceEgp.toStringAsFixed(2)} $currencyStr',
        '${itm.allocatedTransportEgp.toStringAsFixed(2)} $currencyStr',
        '${itm.unitLandedCostEgp.toStringAsFixed(2)} $currencyStr',
        '${itm.markupFactor.toStringAsFixed(3)}x',
      ].join('\t'));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.financialSettlementCopyBreakdownSuccess,
    );
  }
}
