import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/stored_text.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/warehouse_receiving_model.dart';
import '../../providers/goods_in_transit_provider.dart';
import '../../providers/warehouse_receiving_provider.dart';
import '../warehouse_receiving_form_dialog.dart';

/// Helper methods for Warehouse Receiving actions (export, copy, clone, receipt, print, delete)
class WarehouseReceivingActionsHelper {
  static void copyGrnRowTsv(
    BuildContext context,
    WarehouseReceivingModel r,
    AppLocalizations l,
  ) {
    final quarantineText = r.quarantineZoneAssigned ? l.warehouseReceivingQuarantineStatusBlocked : '-';
    final driverTruck = '${r.driverName ?? "-"} (${r.truckPlateNumber ?? "-"})';
    final arrival = r.arrivalDatetime.replaceFirst('T', ' ').split('.').first;

    final rowData = [
      r.grnCode,
      r.warehouseName,
      r.status,
      quarantineText,
      driverTruck,
      arrival,
      r.inspectorName,
      r.discrepancyType,
      r.totalInvoicedQty.toString(),
      r.totalAcceptedQty.toString(),
      r.totalShortageQty.toString(),
      r.totalDamagedQty.toString(),
    ];

    final headers = [
      l.warehouseReceivingColGrnCode,
      l.warehouseReceivingColWarehouse,
      l.warehouseReceivingColStatus,
      l.warehouseReceivingColQuarantine,
      l.warehouseReceivingColTruckDriver,
      l.warehouseReceivingColArrivalDate,
      l.warehouseReceivingColInspector,
      l.warehouseReceivingColDiscrepancy,
      l.warehouseReceivingColInvoicedQty,
      l.warehouseReceivingColAcceptedQty,
      l.warehouseReceivingColShortageQty,
      l.warehouseReceivingColDamagedQty,
    ];

    TableCopyHelper.copyRow(
      context,
      rowData,
      headers: headers,
      includeHeaders: true,
      customMessage: l.copyWarehouseReceivingRowSuccess,
    );
  }

  static void copyGrnTableTsv(
    BuildContext context,
    List<WarehouseReceivingModel> records,
    AppLocalizations l,
  ) {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.warehouseReceivingEmptyRecords, severity: AppSeverity.warning),
      );
      return;
    }

    final headers = [
      l.warehouseReceivingColGrnCode,
      l.warehouseReceivingColWarehouse,
      l.warehouseReceivingColStatus,
      l.warehouseReceivingColQuarantine,
      l.warehouseReceivingColTruckDriver,
      l.warehouseReceivingColArrivalDate,
      l.warehouseReceivingColInspector,
      l.warehouseReceivingColDiscrepancy,
      l.warehouseReceivingColInvoicedQty,
      l.warehouseReceivingColAcceptedQty,
      l.warehouseReceivingColShortageQty,
      l.warehouseReceivingColDamagedQty,
    ];

    final rows = records.map((r) {
      final quarantineText = r.quarantineZoneAssigned ? l.warehouseReceivingQuarantineStatusBlocked : '-';
      final driverTruck = '${r.driverName ?? "-"} (${r.truckPlateNumber ?? "-"})';
      final arrival = r.arrivalDatetime.replaceFirst('T', ' ').split('.').first;
      return [
        r.grnCode,
        r.warehouseName,
        r.status,
        quarantineText,
        driverTruck,
        arrival,
        r.inspectorName,
        r.discrepancyType,
        r.totalInvoicedQty.toString(),
        r.totalAcceptedQty.toString(),
        r.totalShortageQty.toString(),
        r.totalDamagedQty.toString(),
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: l.copyWarehouseReceivingTableSuccess,
    );
  }

  static Future<void> exportGrnExcel(
    BuildContext context,
    List<WarehouseReceivingModel> records,
    AppLocalizations l,
  ) async {
    if (records.isEmpty) return;
    final headers = [
      l.warehouseReceivingColGrnCode,
      l.warehouseReceivingColWarehouse,
      l.warehouseReceivingColStatus,
      l.warehouseReceivingColQuarantine,
      l.warehouseReceivingColTruckDriver,
      l.warehouseReceivingColArrivalDate,
      l.warehouseReceivingColInspector,
      l.warehouseReceivingColDiscrepancy,
      l.warehouseReceivingColInvoicedQty,
      l.warehouseReceivingColAcceptedQty,
      l.warehouseReceivingColShortageQty,
      l.warehouseReceivingColDamagedQty,
    ];

    final rows = records.map((r) {
      final quarantineText = r.quarantineZoneAssigned ? l.warehouseReceivingQuarantineStatusBlocked : '-';
      final driverTruck = '${r.driverName ?? "-"} (${r.truckPlateNumber ?? "-"})';
      final arrival = r.arrivalDatetime.replaceFirst('T', ' ').split('.').first;
      return [
        r.grnCode,
        r.warehouseName,
        r.status,
        quarantineText,
        driverTruck,
        arrival,
        r.inspectorName,
        r.discrepancyType,
        r.totalInvoicedQty.toString(),
        r.totalAcceptedQty.toString(),
        r.totalShortageQty.toString(),
        r.totalDamagedQty.toString(),
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Warehouse Receiving',
      importFileNameOrCode: 'GRN_Registry',
      headers: headers,
      rows: rows,
    );
  }

  static Future<void> exportGrnPdf(
    BuildContext context,
    List<WarehouseReceivingModel> records,
    AppLocalizations l,
  ) async {
    if (records.isEmpty) return;
    final headers = [
      l.warehouseReceivingColGrnCode,
      l.warehouseReceivingColWarehouse,
      l.warehouseReceivingColStatus,
      l.warehouseReceivingColTruckDriver,
      l.warehouseReceivingColArrivalDate,
      l.warehouseReceivingColInspector,
      l.warehouseReceivingColAcceptedQty,
      l.warehouseReceivingColShortageQty,
      l.warehouseReceivingColDamagedQty,
    ];

    final rows = records.map((r) {
      final driverTruck = '${r.driverName ?? "-"} (${r.truckPlateNumber ?? "-"})';
      final arrival = r.arrivalDatetime.replaceFirst('T', ' ').split('.').first;
      return [
        r.grnCode,
        r.warehouseName,
        r.status,
        driverTruck,
        arrival,
        r.inspectorName,
        r.totalAcceptedQty.toString(),
        r.totalShortageQty.toString(),
        r.totalDamagedQty.toString(),
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'Warehouse Receiving',
      importFileNameOrCode: 'GRN_Registry',
      headers: headers,
      rows: rows,
      headerContext: TableExportHeaderContext(
        title: l.wrPdfRegistryTitle,
        subtitle: l.wrPdfRegistrySubtitle,
      ),
    );
  }

  static Future<void> confirmFinalReceipt(
    BuildContext context,
    WidgetRef ref,
    WarehouseReceivingModel record,
  ) async {
    final l10n = context.l10n;
    final confirm = await AppConfirmDialog.show(
      context,
      title: l10n.warehouseReceivingConfirmReceiptTitle,
      message: l10n.warehouseReceivingConfirmReceiptMessage(record.grnCode),
      confirmLabel: l10n.warehouseReceivingConfirmReceiptBtn,
      confirmVariant: AppButtonVariant.success,
      icon: Icons.check_circle,
    );

    if (confirm == true) {
      try {
        final payload = {
          'status': 'Goods Received',
          'discrepancy_notes': storedText.warehouseReceivingStatusGoodsReceived,
        };
        await ref.read(warehouseReceivingProvider.notifier).updateRecord(record.receivingId, payload);
        ref.read(goodsInTransitProvider.notifier).confirmWarehouseReceipt(record.importFileId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l10n.warehouseReceivingConfirmReceiptSuccess(record.grnCode),
              severity: AppSeverity.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, ApiErrorText.of(l10n, e), severity: AppSeverity.danger),
          );
        }
      }
    }
  }

  static void printGrn(
    BuildContext context,
    WarehouseReceivingModel r,
  ) {
    final l = context.l10n;
    final buffer = StringBuffer();
    buffer.writeln('${l.warehouseReceivingColGrnCode}: ${r.grnCode}');
    buffer.writeln('${l.warehouseReceivingColWarehouse}: ${r.warehouseName}');
    buffer.writeln('${l.warehouseReceivingColStatus}: ${r.status}');
    buffer.writeln('${l.warehouseReceivingTruckAndDriver}: ${r.driverName ?? "-"} (${r.truckPlateNumber ?? "-"})');
    buffer.writeln('${l.warehouseReceivingArrivalDatetime}: ${r.arrivalDatetime.replaceFirst("T", " ").split(".")[0]}');
    buffer.writeln('${l.warehouseReceivingInspector}: ${r.inspectorName}');
    buffer.writeln('${l.warehouseReceivingDiscrepancyStatus}: ${r.discrepancyType}');
    buffer.writeln('${l.warehouseReceivingMetricInvoiced}: ${r.totalInvoicedQty}');
    buffer.writeln('${l.warehouseReceivingMetricAccepted}: ${r.totalAcceptedQty}');
    buffer.writeln('${l.warehouseReceivingMetricShortage}: ${r.totalShortageQty}');
    buffer.writeln('${l.warehouseReceivingMetricDamaged}: ${r.totalDamagedQty}');
    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l.warehouseReceivingPrintReceiptSuccess(r.grnCode),
    );
  }

  static Future<void> deleteGrn(
    BuildContext context,
    WidgetRef ref,
    WarehouseReceivingModel r,
  ) async {
    final l = context.l10n;
    final confirm = await AppConfirmDialog.showDelete(
      context,
      title: l.warehouseReceivingDeleteTitle,
      message: l.warehouseReceivingDeleteConfirmMessage,
    );
    if (confirm == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(warehouseReceivingProvider.notifier).softDeleteRecord(r.receivingId);
      } catch (e) {
        if (!context.mounted) return;
        messenger.showSnackBar(
          AppTheme.snackBar(context, ApiErrorText.of(l, e), severity: AppSeverity.danger),
        );
      }
    }
  }

  static void showQuarantineState(
    BuildContext context,
    WarehouseReceivingModel r,
  ) {
    final l = context.l10n;
    final blocked = r.quarantineZoneAssigned;
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        blocked ? l.warehouseReceivingQuarantineAlertBlocked : l.warehouseReceivingQuarantineAlertCleared,
        severity: blocked ? AppSeverity.danger : AppSeverity.success,
      ),
    );
  }

  static void onCloneGrnRecord(
    BuildContext context,
    WarehouseReceivingModel rec,
  ) {
    final l = context.l10n;
    final isAr = l.isArabic;

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: CloneEntityReviewDialog(
            entityType: l.wrCloneEntityType,
            sourceCode: rec.grnCode,
            suggestedNewCode: '',
            sourceTitle: '${rec.warehouseName} (${rec.grnCode})',
            copiedFieldsSummary: {
              l.warehouseReceivingColWarehouse: rec.warehouseName,
              l.warehouseReceivingColTruckDriver: '${rec.driverName ?? "-"} (${rec.truckPlateNumber ?? "-"})',
              l.warehouseReceivingSealNumberLabel: rec.sealNumber ?? '-',
              l.warehouseReceivingSealIntactSwitch:
                  rec.sealIntact ? l.warehouseReceivingSealIntact : l.warehouseReceivingSealBroken,
            },
            mandatorilyResetFields: [
              l.wrCloneResetReceivingId,
              l.wrCloneResetGrnCode,
              l.wrCloneResetArrival,
              l.wrCloneResetStatus,
              l.wrCloneResetQuarantine,
              l.wrCloneResetDiscrepancy,
              l.wrCloneResetInsuranceClaim,
            ],
            allowCopyLineItems: false,
            allowCopyAttachments: false,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              final clonedDraft = WarehouseReceivingModel(
                receivingId: 0,
                grnCode: '',
                importFileId: 0,
                warehouseName: rec.warehouseName,
                arrivalDatetime: DateTime.now().toIso8601String(),
                truckPlateNumber: rec.truckPlateNumber,
                driverName: rec.driverName,
                driverPhone: rec.driverPhone,
                sealNumber: rec.sealNumber,
                sealIntact: rec.sealIntact,
                grnItems: const [],
                totalInvoicedQty: 0,
                totalAcceptedQty: 0,
                totalShortageQty: 0,
                totalDamagedQty: 0,
                discrepancyType: 'None',
                discrepancyNotes: null,
                quarantineZoneAssigned: false,
                insuranceClaimFiled: false,
                insuranceClaimRef: null,
                status: '',
                inspectorName: rec.inspectorName,
                notes: notes,
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
              );

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => WarehouseReceivingFormDialog(
                      recordToEdit: clonedDraft,
                      isCloneDraft: true,
                    ),
                  );
                }
              });
            },
          ),
        ),
      ),
    );
  }
}
