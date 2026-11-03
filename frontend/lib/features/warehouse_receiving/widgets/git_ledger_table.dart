import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/enterprise_data_table/enterprise_data_table.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/goods_in_transit_model.dart';
import 'ops_ui_kit.dart';

/// Goods-in-transit ledger table: consistent row height, numbers aligned to
/// the end edge, codes kept left-to-right and a coloured status chip.
class GitLedgerTable extends StatelessWidget {
  const GitLedgerTable({super.key, required this.items, required this.shipments});

  final List<GitLineItemModel> items;
  final List<ImportFileModel> shipments;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return EnterpriseDataTable<GitLineItemModel>(
      storageKey: 'git_ledger_enterprise_table',
      data: items,
      minWidth: 1500,
      showHeaderToolbar: false,
      showPagination: false,
      columns: [
        EnterpriseColumn<GitLineItemModel>(
          id: 'actions',
          title: l.gitColActions,
          width: 70,
          cellBuilder: (ctx, item, _) {
            final rawCode = item.importFileCode;
            final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: shipments, isArabic: isAr);
            final statusStr = item.isDeliveredToWarehouse ? l.gitStatusDeliveredToWarehouse : l.gitStatusInTransit;
            final rowSummary =
                '$shipTitle\t${item.poNumber}\t${item.itemCode}\t${item.itemName}\t${item.invoicedQty.toStringAsFixed(0)}\t${item.packagesCount} ${item.packageType}\t${item.containersCount} × ${item.containerType}\t${item.certifiedDate}\t$statusStr';
            return Center(
              child: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                tooltip: l.gitCopyRowSummaryBtn,
                onPressed: () => CopyHelper.copy(ctx, rowSummary, customMessage: l.gitCopyRowSummarySuccess),
              ),
            );
          },
        ),
        EnterpriseColumn<GitLineItemModel>(
          id: 'file_code',
          title: l.gitColFileCode,
          width: 220,
          exportValue: (item) => DisplayNameResolver.resolveShipmentTitleByCode(item.importFileCode, shipments: shipments, isArabic: isAr),
          sortComparator: (a, b) => a.importFileCode.compareTo(b.importFileCode),
          cellBuilder: (ctx, item, _) {
            final rawCode = item.importFileCode;
            final shipName = DisplayNameResolver.resolveShipmentNameByCode(rawCode, shipments: shipments, isArabic: isAr);
            final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: shipments, isArabic: isAr);
            final statusStr = item.isDeliveredToWarehouse ? l.gitStatusDeliveredToWarehouse : l.gitStatusInTransit;
            final rowSummary =
                '$shipTitle\t${item.poNumber}\t${item.itemCode}\t${item.itemName}\t${item.invoicedQty.toStringAsFixed(0)}\t${item.packagesCount} ${item.packageType}\t${item.containersCount} × ${item.containerType}\t${item.certifiedDate}\t$statusStr';

            return CopyableTableCell(
              value: shipTitle,
              rowSummary: rowSummary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    shipName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryOf(ctx),
                      fontSize: 12.5,
                    ),
                  ),
                  if (rawCode.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 2),
                      child: InkWell(
                        onTap: () => CopyHelper.copy(ctx, rawCode, customMessage: '${l.gitColFileCode}: $rawCode'),
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
                              Icon(Icons.copy, size: 11, color: AppTheme.textMutedOf(ctx)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        EnterpriseColumn<GitLineItemModel>(
          id: 'po_number',
          title: l.gitColPoNumber,
          width: 170,
          exportValue: (item) => item.poNumber,
          sortComparator: (a, b) => a.poNumber.compareTo(b.poNumber),
          cellBuilder: (ctx, item, _) {
            final rawCode = item.importFileCode;
            final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: shipments, isArabic: isAr);
            final statusStr = item.isDeliveredToWarehouse ? l.gitStatusDeliveredToWarehouse : l.gitStatusInTransit;
            final rowSummary =
                '$shipTitle\t${item.poNumber}\t${item.itemCode}\t${item.itemName}\t${item.invoicedQty.toStringAsFixed(0)}\t${item.packagesCount} ${item.packageType}\t${item.containersCount} × ${item.containerType}\t${item.certifiedDate}\t$statusStr';

            return CopyableTableCell(
              value: item.poNumber,
              rowSummary: rowSummary,
              child: InkWell(
                onTap: () => CopyHelper.copy(ctx, item.poNumber, customMessage: '${l.gitColPoNumber}: ${item.poNumber}'),
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
                    const Icon(Icons.copy, size: 12, color: AppTheme.cobalt),
                  ],
                ),
              ),
            );
          },
        ),
        EnterpriseColumn<GitLineItemModel>(
          id: 'item_code',
          title: l.gitColItemCode,
          width: 160,
          exportValue: (item) => item.itemCode,
          sortComparator: (a, b) => a.itemCode.compareTo(b.itemCode),
          cellBuilder: (ctx, item, _) {
            final rawCode = item.importFileCode;
            final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: shipments, isArabic: isAr);
            final statusStr = item.isDeliveredToWarehouse ? l.gitStatusDeliveredToWarehouse : l.gitStatusInTransit;
            final rowSummary =
                '$shipTitle\t${item.poNumber}\t${item.itemCode}\t${item.itemName}\t${item.invoicedQty.toStringAsFixed(0)}\t${item.packagesCount} ${item.packageType}\t${item.containersCount} × ${item.containerType}\t${item.certifiedDate}\t$statusStr';

            return CopyableTableCell(
              value: item.itemCode,
              rowSummary: rowSummary,
              child: InkWell(
                onTap: () => CopyHelper.copy(ctx, item.itemCode, customMessage: '${l.gitColItemCode}: ${item.itemCode}'),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: LtrText(
                        item.itemCode,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy, size: 12, color: AppTheme.textMutedOf(ctx)),
                  ],
                ),
              ),
            );
          },
        ),
        EnterpriseColumn<GitLineItemModel>(
          id: 'item_name',
          title: l.gitColItemName,
          width: 260,
          exportValue: (item) => item.itemName,
          sortComparator: (a, b) => a.itemName.compareTo(b.itemName),
          cellBuilder: (ctx, item, _) {
            final rawCode = item.importFileCode;
            final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: shipments, isArabic: isAr);
            final statusStr = item.isDeliveredToWarehouse ? l.gitStatusDeliveredToWarehouse : l.gitStatusInTransit;
            final rowSummary =
                '$shipTitle\t${item.poNumber}\t${item.itemCode}\t${item.itemName}\t${item.invoicedQty.toStringAsFixed(0)}\t${item.packagesCount} ${item.packageType}\t${item.containersCount} × ${item.containerType}\t${item.certifiedDate}\t$statusStr';

            return CopyableTableCell(
              value: item.itemName,
              rowSummary: rowSummary,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  item.itemName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            );
          },
        ),
        EnterpriseColumn<GitLineItemModel>(
          id: 'invoiced_qty',
          title: l.gitColInvoicedQty,
          width: 130,
          exportValue: (item) => item.invoicedQty.toStringAsFixed(0),
          sortComparator: (a, b) => a.invoicedQty.compareTo(b.invoicedQty),
          cellBuilder: (ctx, item, _) {
            final rawCode = item.importFileCode;
            final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: shipments, isArabic: isAr);
            final statusStr = item.isDeliveredToWarehouse ? l.gitStatusDeliveredToWarehouse : l.gitStatusInTransit;
            final rowSummary =
                '$shipTitle\t${item.poNumber}\t${item.itemCode}\t${item.itemName}\t${item.invoicedQty.toStringAsFixed(0)}\t${item.packagesCount} ${item.packageType}\t${item.containersCount} × ${item.containerType}\t${item.certifiedDate}\t$statusStr';
            final qtyText = l.gitKpiQuantityValue(item.invoicedQty.toStringAsFixed(0));

            return CopyableTableCell(
              value: item.invoicedQty.toStringAsFixed(0),
              rowSummary: rowSummary,
              child: Text(qtyText, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.cobalt)),
            );
          },
        ),
        EnterpriseColumn<GitLineItemModel>(
          id: 'packages_count',
          title: l.gitColPackagesCount,
          width: 140,
          exportValue: (item) => '${item.packagesCount} ${item.packageType}',
          sortComparator: (a, b) => a.packagesCount.compareTo(b.packagesCount),
          cellBuilder: (ctx, item, _) {
            final rawCode = item.importFileCode;
            final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: shipments, isArabic: isAr);
            final statusStr = item.isDeliveredToWarehouse ? l.gitStatusDeliveredToWarehouse : l.gitStatusInTransit;
            final rowSummary =
                '$shipTitle\t${item.poNumber}\t${item.itemCode}\t${item.itemName}\t${item.invoicedQty.toStringAsFixed(0)}\t${item.packagesCount} ${item.packageType}\t${item.containersCount} × ${item.containerType}\t${item.certifiedDate}\t$statusStr';
            final packages = '${item.packagesCount} ${item.packageType}';

            return CopyableTableCell(
              value: packages,
              rowSummary: rowSummary,
              child: Text(packages),
            );
          },
        ),
        EnterpriseColumn<GitLineItemModel>(
          id: 'containers',
          title: l.gitColContainers,
          width: 140,
          exportValue: (item) => '${item.containersCount} × ${item.containerType}',
          sortComparator: (a, b) => a.containersCount.compareTo(b.containersCount),
          cellBuilder: (ctx, item, _) {
            final rawCode = item.importFileCode;
            final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: shipments, isArabic: isAr);
            final statusStr = item.isDeliveredToWarehouse ? l.gitStatusDeliveredToWarehouse : l.gitStatusInTransit;
            final rowSummary =
                '$shipTitle\t${item.poNumber}\t${item.itemCode}\t${item.itemName}\t${item.invoicedQty.toStringAsFixed(0)}\t${item.packagesCount} ${item.packageType}\t${item.containersCount} × ${item.containerType}\t${item.certifiedDate}\t$statusStr';
            final containers = '${item.containersCount} × ${item.containerType}';

            return CopyableTableCell(
              value: containers,
              rowSummary: rowSummary,
              child: Text(containers),
            );
          },
        ),
        EnterpriseColumn<GitLineItemModel>(
          id: 'certified_date',
          title: l.gitColCertifiedDate,
          width: 150,
          exportValue: (item) => item.certifiedDate,
          sortComparator: (a, b) => a.certifiedDate.compareTo(b.certifiedDate),
          cellBuilder: (ctx, item, _) {
            final rawCode = item.importFileCode;
            final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: shipments, isArabic: isAr);
            final statusStr = item.isDeliveredToWarehouse ? l.gitStatusDeliveredToWarehouse : l.gitStatusInTransit;
            final rowSummary =
                '$shipTitle\t${item.poNumber}\t${item.itemCode}\t${item.itemName}\t${item.invoicedQty.toStringAsFixed(0)}\t${item.packagesCount} ${item.packageType}\t${item.containersCount} × ${item.containerType}\t${item.certifiedDate}\t$statusStr';

            return CopyableTableCell(
              value: item.certifiedDate,
              rowSummary: rowSummary,
              child: LtrText(item.certifiedDate),
            );
          },
        ),
        EnterpriseColumn<GitLineItemModel>(
          id: 'ledger_status',
          title: l.gitColLedgerStatus,
          width: 170,
          exportValue: (item) => item.isDeliveredToWarehouse ? l.gitStatusDeliveredToWarehouse : l.gitStatusInTransit,
          sortComparator: (a, b) => (a.isDeliveredToWarehouse == b.isDeliveredToWarehouse) ? 0 : (a.isDeliveredToWarehouse ? 1 : -1),
          cellBuilder: (ctx, item, _) {
            final rawCode = item.importFileCode;
            final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: shipments, isArabic: isAr);
            final isDelivered = item.isDeliveredToWarehouse;
            final statusStr = isDelivered ? l.gitStatusDeliveredToWarehouse : l.gitStatusInTransit;
            final rowSummary =
                '$shipTitle\t${item.poNumber}\t${item.itemCode}\t${item.itemName}\t${item.invoicedQty.toStringAsFixed(0)}\t${item.packagesCount} ${item.packageType}\t${item.containersCount} × ${item.containerType}\t${item.certifiedDate}\t$statusStr';

            return CopyableTableCell(
              value: statusStr,
              rowSummary: rowSummary,
              child: OpsStatusChip(
                label: statusStr,
                severity: isDelivered ? AppSeverity.success : AppSeverity.info,
                icon: isDelivered ? Icons.check_circle_outline : Icons.local_shipping_outlined,
              ),
            );
          },
        ),
      ],
    );
  }
}
