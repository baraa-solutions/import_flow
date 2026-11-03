import 'package:flutter/material.dart';

import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../models/cargo_shipping_model.dart';

class CargoShippingRegistryExportHelper {
  static void copyRowTsv({
    required BuildContext context,
    required CargoShippingModel rec,
    required AppLocalizations l,
  }) {
    final containerSummary = rec.containersLoadingData
        .map((c) => '${c.containerNo} (${c.containerType})')
        .join(', ');
    final gatedCount = rec.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
    final hasBreach = rec.containersLoadingData.any((c) => c.isSlaBreached) || (rec.lclTrackingData?.isSlaBreached ?? false);

    final rowData = [
      rec.cargoShippingCode,
      rec.importFileCode ?? 'IMP-${rec.importFileId}',
      rec.companyName ?? '',
      rec.shipmentType,
      containerSummary,
      rec.status,
      '$gatedCount/${rec.containersLoadingData.length}',
      hasBreach ? l.cargoShippingSlaBreached : l.cargoShippingSlaOnTime,
      rec.isActive ? l.cshStateActive : l.cshStateDeleted,
    ];

    final headers = [
      l.cshColCode,
      l.cshColImportFile,
      l.cshColCompany,
      l.cshColShipType,
      l.cshColContainersSeals,
      l.cshColStatus,
      l.cshColGateIn,
      l.cshColSla,
      l.cshColOp,
    ];

    TableCopyHelper.copyRow(
      context,
      rowData,
      headers: headers,
      includeHeaders: true,
      customMessage: l.copyCargoShippingRowSuccess,
    );
  }

  static void copyTableTsv({
    required BuildContext context,
    required List<CargoShippingModel> records,
    required AppLocalizations l,
  }) {
    final headers = [
      l.cshColCode,
      l.cshColImportFile,
      l.cshColCompany,
      l.cshColShipType,
      l.cshColContainers,
      l.cshColTotalVgm,
      l.cshColStatus,
      l.cshColGateIn,
      l.cshColSla,
      l.cshColOp,
    ];

    final rows = records.map((r) {
      final containerSummary = r.containersLoadingData
          .map((c) => '${c.containerNo} (${c.containerType})')
          .join(', ');
      final totalVgm = r.containersLoadingData.fold<double>(0.0, (acc, c) => acc + c.grossWeightKg);
      final gatedCount = r.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
      final hasBreach = r.containersLoadingData.any((c) => c.isSlaBreached) || (r.lclTrackingData?.isSlaBreached ?? false);

      return [
        r.cargoShippingCode,
        r.importFileCode ?? 'IMP-${r.importFileId}',
        r.companyName ?? '',
        r.shipmentType,
        containerSummary,
        l.cshWeightKg(totalVgm.toStringAsFixed(0)),
        r.status,
        '$gatedCount/${r.containersLoadingData.length}',
        hasBreach ? l.cargoShippingSlaBreached : l.cargoShippingSlaOnTime,
        r.isActive ? l.cshStateActive : l.cshStateDeleted,
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: l.copyCargoShippingTableSuccess,
    );
  }

  static Future<void> exportExcel({
    required BuildContext context,
    required List<CargoShippingModel> records,
    required AppLocalizations l,
  }) async {
    final headers = [
      l.cshColCode,
      l.cshColImportFile,
      l.cshColCompany,
      l.cshColShipType,
      l.cshColContainers,
      l.cshColTotalVgm,
      l.cshColStatus,
      l.cshColGateIn,
      l.cshColSla,
      l.cshColOp,
    ];

    final rows = records.map((r) {
      final containerSummary = r.containersLoadingData
          .map((c) => '${c.containerNo} (${c.containerType})')
          .join(', ');
      final totalVgm = r.containersLoadingData.fold<double>(0.0, (acc, c) => acc + c.grossWeightKg);
      final gatedCount = r.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
      final hasBreach = r.containersLoadingData.any((c) => c.isSlaBreached) || (r.lclTrackingData?.isSlaBreached ?? false);

      return [
        r.cargoShippingCode,
        r.importFileCode ?? 'IMP-${r.importFileId}',
        r.companyName ?? '',
        r.shipmentType,
        containerSummary,
        l.cshWeightKg(totalVgm.toStringAsFixed(0)),
        r.status,
        '$gatedCount/${r.containersLoadingData.length}',
        hasBreach ? l.cargoShippingSlaBreached : l.cargoShippingSlaOnTime,
        r.isActive ? l.cshStateActive : l.cshStateDeleted,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Cargo Shipping',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
    );
  }

  static Future<void> exportPdf({
    required BuildContext context,
    required List<CargoShippingModel> records,
    required AppLocalizations l,
  }) async {
    final headers = [
      l.cshColCode,
      l.cshColImportFile,
      l.cshColCompany,
      l.cshColShipType,
      l.cshColContainersShort,
      l.cshColWeightShort,
      l.cshColStatus,
      l.cshColGateInShort,
      l.cshColSlaShort,
    ];

    final rows = records.map((r) {
      final containerSummary = r.containersLoadingData
          .map((c) => '${c.containerNo} (${c.containerType})')
          .join(', ');
      final totalVgm = r.containersLoadingData.fold<double>(0.0, (acc, c) => acc + c.grossWeightKg);
      final gatedCount = r.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
      final hasBreach = r.containersLoadingData.any((c) => c.isSlaBreached) || (r.lclTrackingData?.isSlaBreached ?? false);

      return [
        r.cargoShippingCode,
        r.importFileCode ?? 'IMP-${r.importFileId}',
        r.companyName ?? '—',
        r.shipmentType,
        containerSummary.isNotEmpty ? containerSummary : '—',
        l.cshWeightKg(totalVgm.toStringAsFixed(0)),
        r.status,
        '$gatedCount/${r.containersLoadingData.length}',
        hasBreach ? l.cargoShippingSlaBreached : l.cargoShippingSlaOnTime,
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'Cargo Shipping',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
      headerContext: TableExportHeaderContext(
        title: l.cshPdfTitle,
        subtitle: l.cshPdfSubtitle,
        metadata: {
          l.cshPdfMetaTotal: records.length.toString(),
          l.cshPdfMetaFcl: records.where((r) => r.shipmentType == 'FCL').length.toString(),
          l.cshPdfMetaLcl: records.where((r) => r.shipmentType == 'LCL').length.toString(),
        },
      ),
    );
  }
}
