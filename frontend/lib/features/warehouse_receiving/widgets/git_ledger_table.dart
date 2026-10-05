import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';
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
    const head = OpsTableStyle.heading;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: OpsTableStyle.headingColor(context),
        headingRowHeight: OpsTableStyle.headingHeight,
        dataRowMinHeight: OpsTableStyle.rowMinHeight,
        dataRowMaxHeight: OpsTableStyle.rowMaxHeight,
        columnSpacing: 22,
        columns: [
          DataColumn(label: head(context, l.gitColActions)),
          DataColumn(label: head(context, l.gitColFileCode)),
          DataColumn(label: head(context, l.gitColPoNumber)),
          DataColumn(label: head(context, l.gitColItemCode)),
          DataColumn(label: head(context, l.gitColItemName)),
          DataColumn(label: head(context, l.gitColInvoicedQty), numeric: true),
          DataColumn(label: head(context, l.gitColPackagesCount), numeric: true),
          DataColumn(label: head(context, l.gitColContainers), numeric: true),
          DataColumn(label: head(context, l.gitColCertifiedDate)),
          DataColumn(label: head(context, l.gitColLedgerStatus)),
        ],
        rows: items.map((item) {
          final rawCode = item.importFileCode;
          final shipName = DisplayNameResolver.resolveShipmentNameByCode(rawCode, shipments: shipments, isArabic: isAr);
          final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: shipments, isArabic: isAr);
          final isDelivered = item.isDeliveredToWarehouse;
          final statusStr = isDelivered ? l.gitStatusDeliveredToWarehouse : l.gitStatusInTransit;
          final rowSummary =
              '$shipTitle\t${item.poNumber}\t${item.itemCode}\t${item.itemName}\t${item.invoicedQty.toStringAsFixed(0)}\t${item.packagesCount} ${item.packageType}\t${item.containersCount} × ${item.containerType}\t${item.certifiedDate}\t$statusStr';
          final packages = '${item.packagesCount} ${item.packageType}';
          final containers = '${item.containersCount} × ${item.containerType}';
          final qtyText = l.gitKpiQuantityValue(item.invoicedQty.toStringAsFixed(0));

          return DataRow(cells: [
            DataCell(
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                tooltip: l.gitCopyRowSummaryBtn,
                onPressed: () => CopyHelper.copy(context, rowSummary, customMessage: l.gitCopyRowSummarySuccess),
              ),
            ),
            DataCell(
              CopyableTableCell(
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
                        color: AppTheme.textPrimaryOf(context),
                        fontSize: 12.5,
                      ),
                    ),
                    if (rawCode.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 2),
                        child: InkWell(
                          onTap: () => CopyHelper.copy(context, rawCode, customMessage: '${l.gitColFileCode}: $rawCode'),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          child: Container(
                            padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceAltOf(context),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              border: Border.all(color: AppTheme.borderOf(context)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LtrText(
                                  rawCode,
                                  style: TextStyle(
                                    fontSize: DisplayDensityMode.clampFontSize(11.0),
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondaryOf(context),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.copy, size: 11, color: AppTheme.textMutedOf(context)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            DataCell(
              CopyableTableCell(
                value: item.poNumber,
                rowSummary: rowSummary,
                child: InkWell(
                  onTap: () => CopyHelper.copy(context, item.poNumber, customMessage: '${l.gitColPoNumber}: ${item.poNumber}'),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LtrText(item.poNumber, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.cobalt)),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy, size: 12, color: AppTheme.cobalt),
                    ],
                  ),
                ),
              ),
            ),
            DataCell(
              CopyableTableCell(
                value: item.itemCode,
                rowSummary: rowSummary,
                child: InkWell(
                  onTap: () => CopyHelper.copy(context, item.itemCode, customMessage: '${l.gitColItemCode}: ${item.itemCode}'),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LtrText(item.itemCode, style: const TextStyle(fontFamily: 'monospace')),
                      const SizedBox(width: 4),
                      Icon(Icons.copy, size: 12, color: AppTheme.textMutedOf(context)),
                    ],
                  ),
                ),
              ),
            ),
            DataCell(
              CopyableTableCell(
                value: item.itemName,
                rowSummary: rowSummary,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    item.itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            DataCell(
              CopyableTableCell(
                value: item.invoicedQty.toStringAsFixed(0),
                rowSummary: rowSummary,
                child: Text(qtyText, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.cobalt)),
              ),
            ),
            DataCell(CopyableTableCell(value: packages, rowSummary: rowSummary, child: Text(packages))),
            DataCell(CopyableTableCell(value: containers, rowSummary: rowSummary, child: Text(containers))),
            DataCell(CopyableTableCell(value: item.certifiedDate, rowSummary: rowSummary, child: LtrText(item.certifiedDate))),
            DataCell(
              CopyableTableCell(
                value: statusStr,
                rowSummary: rowSummary,
                child: OpsStatusChip(
                  label: statusStr,
                  severity: isDelivered ? AppSeverity.success : AppSeverity.info,
                  icon: isDelivered ? Icons.check_circle_outline : Icons.local_shipping_outlined,
                ),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}
