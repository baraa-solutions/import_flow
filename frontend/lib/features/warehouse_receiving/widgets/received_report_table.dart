import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';
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

  Widget _qty(BuildContext context, String value, Color? color, {String? summary, String? text}) {
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
          DataColumn(label: head(context, l.whReportColImportFile)),
          DataColumn(label: head(context, l.whReportColPoNumber)),
          DataColumn(label: head(context, l.whReportColContainerAndTruck)),
          DataColumn(label: head(context, l.whReportColItemAndDescription)),
          DataColumn(label: head(context, l.whReportColInvoicedQty), numeric: true),
          DataColumn(label: head(context, l.whReportColShortageQty), numeric: true),
          DataColumn(label: head(context, l.whReportColDamagedQty), numeric: true),
          DataColumn(label: head(context, l.whReportColSamplesQty), numeric: true),
          DataColumn(label: head(context, l.whReportColReceivedQty), numeric: true),
          DataColumn(label: head(context, l.whReportColVarianceQty), numeric: true),
          DataColumn(label: head(context, l.whReportColReceiptStatus)),
          DataColumn(label: head(context, l.whReportColActions)),
        ],
        rows: items.map((item) {
          final rawCode = item.importFileCode;
          final shipName = DisplayNameResolver.resolveShipmentNameByCode(rawCode, shipments: shipments, isArabic: isAr);
          final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: shipments, isArabic: isAr);
          final variance = item.varianceQty;
          final rowSummary = item.toRowSummary(l);
          final varianceText = '${variance >= 0 ? "+" : ""}$variance';

          return DataRow(cells: [
            DataCell(
              CopyableTableCell(
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
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context), fontSize: 12.5),
                      ),
                      const SizedBox(height: 2),
                    ],
                    if (rawCode.isNotEmpty)
                      InkWell(
                        onTap: () => CopyHelper.copy(
                          context,
                          rawCode,
                          customMessage: l.whReportCopyBadgeSuccess(l.whReportColImportFile, rawCode),
                        ),
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
                  ],
                ),
              ),
            ),
            DataCell(
              CopyableTableCell(
                value: item.poNumber,
                rowSummary: rowSummary,
                child: InkWell(
                  onTap: () => CopyHelper.copy(
                    context,
                    item.poNumber,
                    customMessage: l.whReportCopyBadgeSuccess(l.whReportColPoNumber, item.poNumber),
                  ),
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
            DataCell(CopyableTableCell(value: item.containerInfo, rowSummary: rowSummary, child: Text(item.containerInfo))),
            DataCell(
              CopyableTableCell(
                value: '${item.itemCode} - ${item.itemName}',
                rowSummary: rowSummary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => CopyHelper.copy(
                        context,
                        item.itemCode,
                        customMessage: l.whReportCopyBadgeSuccess(l.whReportColItemAndDescription, item.itemCode),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LtrText(
                            item.itemCode,
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 11.5),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.copy, size: 10, color: AppTheme.textMutedOf(context)),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        item.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            DataCell(_qty(context, '${item.invoicedQty}', null, summary: rowSummary)),
            DataCell(_qty(context, '${item.shortageQty}', item.shortageQty > 0 ? AppTheme.orange : null, summary: rowSummary)),
            DataCell(_qty(context, '${item.damagedQty}', item.damagedQty > 0 ? AppTheme.crimson : null, summary: rowSummary)),
            DataCell(_qty(context, '${item.samplesQty}', item.samplesQty > 0 ? AppTheme.cobalt : null, summary: rowSummary)),
            DataCell(_qty(context, '${item.receivedQty}', AppTheme.emerald, summary: rowSummary)),
            DataCell(
              _qty(
                context,
                varianceText,
                variance == 0 ? AppTheme.emerald : (variance < 0 ? AppTheme.crimson : AppTheme.cobalt),
                summary: rowSummary,
              ),
            ),
            DataCell(
              CopyableTableCell(
                value: l.whReportStatusApprovedAndReceived,
                rowSummary: rowSummary,
                child: OpsStatusChip(
                  label: l.whReportStatusApprovedAndReceived,
                  severity: AppSeverity.success,
                  icon: Icons.verified_outlined,
                ),
              ),
            ),
            DataCell(
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                tooltip: l.whReportCopyRowSummaryBtn,
                onPressed: () => CopyHelper.copy(context, rowSummary, customMessage: l.whReportCopyRowSummarySuccess),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}
