import 'package:flutter/material.dart';
import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../services/customs_declaration46_calculator.dart';
import 'registry_item.dart';

class RegistryExportHelper {
  static void copyRegistryTableTsv(
    BuildContext context,
    List<DeclarationRegistryItem> items,
    AppLocalizations l,
  ) {
    final miss = l.idocBMissing;
    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclColRegistrationDate,
      l.ccDecOfficeLabel,
      l.customsDeclChannelLabel,
      l.customsDeclColDeclarationStatus,
      l.customsDeclColTariffEstimate,
      l.customsDeclColVariance,
    ];

    final rows = items.map((a) {
      final vr = a.varianceResult;
      final pctText = vr.diffPercentage != null
          ? '${vr.diffPercentage! >= 0 ? '+' : ''}${vr.diffPercentage!.toStringAsFixed(1)}%'
          : l.customsDeclVariancePending;
      return [
        a.declarationNo,
        a.importFileCode,
        a.supplierName,
        a.declarationDate,
        a.customsOffice,
        a.channel,
        a.status,
        a.estimatedDutyTotal.fixedOrMissing(2, miss),
        pctText,
      ];
    }).toList();

    TableCopyHelper.copyTable(context, headers, rows);
  }

  static Future<void> exportRegistryExcel(
    BuildContext context,
    List<DeclarationRegistryItem> items,
    AppLocalizations l,
  ) async {
    final miss = l.idocBMissing;
    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclColRegistrationDate,
      l.ccDecOfficeLabel,
      l.customsDeclChannelLabel,
      l.customsDeclColDeclarationStatus,
      l.customsDeclColTariffEstimate,
      l.customsDeclColVariance,
    ];

    final rows = items.map((a) {
      final vr = a.varianceResult;
      final pctText = vr.diffPercentage != null
          ? '${vr.diffPercentage! >= 0 ? '+' : ''}${vr.diffPercentage!.toStringAsFixed(1)}%'
          : l.customsDeclVariancePending;
      return [
        a.declarationNo,
        a.importFileCode,
        a.supplierName,
        a.declarationDate,
        a.customsOffice,
        a.channel,
        a.status,
        a.estimatedDutyTotal.fixedOrMissing(2, miss),
        pctText,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Customs Declarations 46 Registry',
      importFileNameOrCode: 'ALL-FILES',
    );
  }

  static Future<void> exportRegistryPdf(
    BuildContext context,
    List<DeclarationRegistryItem> items,
    AppLocalizations l,
  ) async {
    final miss = l.idocBMissing;
    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclColRegistrationDate,
      l.ccDecOfficeLabel,
      l.customsDeclChannelLabel,
      l.customsDeclColDeclarationStatus,
      l.customsDeclColTariffEstimate,
      l.customsDeclColVariance,
    ];

    final rows = items.map((a) {
      final vr = a.varianceResult;
      final pctText = vr.diffPercentage != null
          ? '${vr.diffPercentage! >= 0 ? '+' : ''}${vr.diffPercentage!.toStringAsFixed(1)}%'
          : l.customsDeclVariancePending;
      return [
        a.declarationNo,
        a.importFileCode,
        a.supplierName,
        a.declarationDate,
        a.customsOffice,
        a.channel,
        a.status,
        a.estimatedDutyTotal.egpOrMissing(miss),
        pctText,
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Customs Declarations 46 Registry',
      importFileNameOrCode: 'ALL-FILES',
      headerContext: TableExportHeaderContext(
        title: l.customsDeclTabRegistry,
        subtitle: l.customsDeclExportSubtitle,
        metadata: {
          l.customsDeclExportMetaTotal: items.length.toString(),
          l.customsDeclExportMetaGeneratedAt: DateTime.now().toString().substring(0, 19),
        },
      ),
    );
  }
}
