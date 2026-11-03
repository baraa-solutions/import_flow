import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/enterprise_data_table/enterprise_data_table.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../import_files/models/import_file_model.dart';
import '../services/warehouse_received_report_export_service.dart';
import 'ops_ui_kit.dart';

/// Received-shipments audit table: numeric columns aligned to the end edge,
/// variance / shortage / damage coloured by severity, status as a chip.
class ReceivedReportTable extends StatelessWidget {
  const ReceivedReportTable({super.key, required this.items, required this.shipments});

  final List<WarehouseReceivedReportItem> items;
  final List<ImportFileModel> shipments;

  static Widget _qty(BuildContext context, String value, Color? color, {String? summary, String? text}) {
    return CopyableTableCell(
      value: value,
      rowSummary: summary,
      child: Text(
        text ?? value,
        style: TextStyle(fontWeight: FontWeight.w700, color: color ?? AppTheme.textPrimaryOf(context)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return EnterpriseDataTable<WarehouseReceivedReportItem>(
      storageKey: 'received_report_enterprise_table',
      data: items,
      minWidth: 1600,
      showHeaderToolbar: false,
      showPagination: false,
      columns: [
        EnterpriseColumn<WarehouseReceivedReportItem>(
          id: 'import_file',
          title: l.whReportColImportFile,
          width: 200,
          exportValue: (item) => DisplayNameResolver.resolveShipmentTitleByCode(item.importFileCode, shipments: shipments, isArabic: isAr),
          sortComparator: (a, b) => a.importFileCode.compareTo(b.importFileCode),
          cellBuilder: (ctx, item, _) {
            final rawCode = item.importFileCode;
            final shipName = DisplayNameResolver.resolveShipmentNameByCode(rawCode, shipments: shipments, isArabic: isAr);
            final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: shipments, isArabic: isAr);
            final rowSummary = item.toRowSummary(l);

            return CopyableTableCell(
              value: shipTitle,
              rowSummary: rowSummary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (shipName != rawCode) ...[
                    Text(
                      shipName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(ctx), fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                  ],
                  if (rawCode.isNotEmpty)
                    InkWell(
                      onTap: () => CopyHelper.copy(
                        ctx,
                        rawCode,
                        customMessage: l.whReportCopyBadgeSuccess(l.whReportColImportFile, rawCode),
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: Container(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAltOf(ctx),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(color: AppTheme.borderOf(ctx)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: LtrText(
                                rawCode,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: DisplayDensityMode.clampFontSize(11.0),
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondaryOf(ctx),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.copy, size: 10, color: AppTheme.textMutedOf(ctx)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        EnterpriseColumn<WarehouseReceivedReportItem>(
          id: 'po_number',
          title: l.whReportColPoNumber,
          width: 170,
          exportValue: (item) => item.poNumber.isNotEmpty ? item.poNumber : '—',
          sortComparator: (a, b) => a.poNumber.compareTo(b.poNumber),
          cellBuilder: (ctx, item, _) {
            final rowSummary = item.toRowSummary(l);
            return CopyableTableCell(
              value: item.poNumber.isNotEmpty ? item.poNumber : '—',
              rowSummary: rowSummary,
              child: item.poNumber.isNotEmpty
                  ? InkWell(
                      onTap: () => CopyHelper.copy(
                        ctx,
                        item.poNumber,
                        customMessage: l.whReportCopyBadgeSuccess(l.whReportColPoNumber, item.poNumber),
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: LtrText(
                              item.poNumber,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.cobalt),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy, size: 11, color: AppTheme.cobalt),
                        ],
                      ),
                    )
                  : const Text('—'),
            );
          },
        ),
        EnterpriseColumn<WarehouseReceivedReportItem>(
          id: 'truck_plate',
          title: l.warehouseReceivingTruckPlateLabel,
          width: 130,
          exportValue: (item) => item.truckPlateNumber.isNotEmpty ? item.truckPlateNumber : '—',
          sortComparator: (a, b) => a.truckPlateNumber.compareTo(b.truckPlateNumber),
          cellBuilder: (ctx, item, _) {
            final rowSummary = item.toRowSummary(l);
            return CopyableTableCell(
              value: item.truckPlateNumber.isNotEmpty ? item.truckPlateNumber : '—',
              rowSummary: rowSummary,
              child: Text(item.truckPlateNumber.isNotEmpty ? item.truckPlateNumber : '—'),
            );
          },
        ),
        EnterpriseColumn<WarehouseReceivedReportItem>(
          id: 'item_desc',
          title: l.whReportColItemAndDescription,
          width: 260,
          exportValue: (item) => '${item.itemCode} - ${item.itemName}',
          sortComparator: (a, b) => a.itemCode.compareTo(b.itemCode),
          cellBuilder: (ctx, item, _) {
            final rowSummary = item.toRowSummary(l);
            return CopyableTableCell(
              value: '${item.itemCode} - ${item.itemName}',
              rowSummary: rowSummary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => CopyHelper.copy(
                      ctx,
                      item.itemCode,
                      customMessage: l.whReportCopyBadgeSuccess(l.whReportColItemAndDescription, item.itemCode),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: LtrText(
                            item.itemCode,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 11.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.copy, size: 10, color: AppTheme.textMutedOf(ctx)),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(
                      item.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(ctx)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        EnterpriseColumn<WarehouseReceivedReportItem>(
          id: 'invoiced_qty',
          title: l.whReportColInvoicedQty,
          width: 110,
          exportValue: (item) => '${item.invoicedQty}',
          sortComparator: (a, b) => a.invoicedQty.compareTo(b.invoicedQty),
          cellBuilder: (ctx, item, _) => _qty(ctx, '${item.invoicedQty}', null, summary: item.toRowSummary(l)),
        ),
        EnterpriseColumn<WarehouseReceivedReportItem>(
          id: 'shortage_qty',
          title: l.whReportColShortageQty,
          width: 105,
          exportValue: (item) => '${item.shortageQty}',
          sortComparator: (a, b) => a.shortageQty.compareTo(b.shortageQty),
          cellBuilder: (ctx, item, _) => _qty(
            ctx,
            '${item.shortageQty}',
            item.shortageQty > 0 ? AppTheme.orange : null,
            summary: item.toRowSummary(l),
          ),
        ),
        EnterpriseColumn<WarehouseReceivedReportItem>(
          id: 'damaged_qty',
          title: l.whReportColDamagedQty,
          width: 105,
          exportValue: (item) => '${item.damagedQty}',
          sortComparator: (a, b) => a.damagedQty.compareTo(b.damagedQty),
          cellBuilder: (ctx, item, _) => _qty(
            ctx,
            '${item.damagedQty}',
            item.damagedQty > 0 ? AppTheme.crimson : null,
            summary: item.toRowSummary(l),
          ),
        ),
        EnterpriseColumn<WarehouseReceivedReportItem>(
          id: 'received_qty',
          title: l.whReportColReceivedQty,
          width: 110,
          exportValue: (item) => '${item.receivedQty}',
          sortComparator: (a, b) => a.receivedQty.compareTo(b.receivedQty),
          cellBuilder: (ctx, item, _) => _qty(
            ctx,
            '${item.receivedQty}',
            AppTheme.emerald,
            summary: item.toRowSummary(l),
          ),
        ),
        EnterpriseColumn<WarehouseReceivedReportItem>(
          id: 'variance_qty',
          title: l.whReportColVarianceQty,
          width: 110,
          exportValue: (item) => '${item.varianceQty >= 0 ? "+" : ""}${item.varianceQty}',
          sortComparator: (a, b) => a.varianceQty.compareTo(b.varianceQty),
          cellBuilder: (ctx, item, _) {
            final variance = item.varianceQty;
            final varianceText = '${variance >= 0 ? "+" : ""}$variance';
            return _qty(
              ctx,
              varianceText,
              variance == 0 ? AppTheme.emerald : (variance < 0 ? AppTheme.crimson : AppTheme.cobalt),
              summary: item.toRowSummary(l),
            );
          },
        ),
        EnterpriseColumn<WarehouseReceivedReportItem>(
          id: 'status',
          title: l.whReportColReceiptStatus,
          width: 180,
          exportValue: (item) => DomainEnums.label(
            l,
            DomainEnumType.warehouseReceivingStatus,
            item.status,
            fallback: item.status,
          ),
          sortComparator: (a, b) => a.status.compareTo(b.status),
          cellBuilder: (ctx, item, _) {
            final rowSummary = item.toRowSummary(l);
            final statusLabel = DomainEnums.label(
              l,
              DomainEnumType.warehouseReceivingStatus,
              item.status,
              fallback: item.status,
            );
            final code = DomainEnums.legacyToCode(DomainEnumType.warehouseReceivingStatus, item.status) ?? item.status;
            AppSeverity severity;
            IconData icon;
            switch (code) {
              case 'INSPECTION_PASSED':
              case 'GOODS_RECEIVED':
              case 'CLOSED':
              case 'GRN_AUDITED':
                severity = AppSeverity.success;
                icon = Icons.verified_outlined;
                break;
              case 'DISCREPANCY_REPORTED':
                severity = AppSeverity.warning;
                icon = Icons.warning_amber_rounded;
                break;
              case 'UNDER_QUARANTINE_INSPECTION':
              case 'UNDER_BOND_QUARANTINE':
                severity = AppSeverity.danger;
                icon = Icons.lock_clock_outlined;
                break;
              case 'PENDING_COUNT':
              default:
                severity = AppSeverity.info;
                icon = Icons.pending_actions_outlined;
                break;
            }
            return CopyableTableCell(
              value: statusLabel,
              rowSummary: rowSummary,
              child: OpsStatusChip(
                label: statusLabel,
                severity: severity,
                icon: icon,
              ),
            );
          },
        ),
        EnterpriseColumn<WarehouseReceivedReportItem>(
          id: 'actions',
          title: l.whReportColActions,
          width: 70,
          cellBuilder: (ctx, item, _) {
            final rowSummary = item.toRowSummary(l);
            return Center(
              child: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                tooltip: l.whReportCopyRowSummaryBtn,
                onPressed: () => CopyHelper.copy(ctx, rowSummary, customMessage: l.whReportCopyRowSummarySuccess),
              ),
            );
          },
        ),
      ],
    );
  }
}
