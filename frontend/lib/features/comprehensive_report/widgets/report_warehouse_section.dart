import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/widgets.dart';
import '../../warehouse_receiving/models/warehouse_receiving_model.dart';
import 'report_card_container.dart';
import 'report_copy_badge.dart';

/// Warehouse receiving & GRN data section for Comprehensive Report.
class ReportWarehouseSection extends StatelessWidget {
  final AsyncValue<List<WarehouseReceivingModel>> state;

  const ReportWarehouseSection({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ReportCardContainer(
      title: l.compReportSecWarehouse,
      icon: Icons.warehouse_outlined,
      iconColor: AppTheme.emerald,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Text('${l.errorPrefix} $err', style: const TextStyle(color: AppTheme.crimson)),
        data: (list) {
          if (list.isEmpty) return Text(l.compReportNoWarehouseData, style: const TextStyle(color: Colors.grey));
          final wh = list.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ReportCopyBadge(
                    textToCopy: wh.grnCode,
                    label: l.compReportGrnChip(wh.grnCode),
                    color: AppTheme.charcoal.withValues(alpha: 0.1),
                    borderColor: AppTheme.charcoal.withValues(alpha: 0.3),
                    textColor: AppTheme.charcoal,
                  ),
                  const SizedBox(width: 16),
                  Text(wh.warehouseName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(l.compReportArrivalDatetime(wh.arrivalDatetime), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 16),
                  Text(l.compReportInspectorPrefix(wh.inspectorName), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniStat(l.compReportQtyInvoiced, wh.totalInvoicedQty.toString()),
                  _miniStat(l.compReportQtyAccepted, wh.totalAcceptedQty.toString()),
                  _miniStat(l.compReportQtyShortage, wh.totalShortageQty.toString()),
                  _miniStat(l.compReportQtyDamaged, wh.totalDamagedQty.toString()),
                ],
              ),
              const SizedBox(height: 12),
              if (wh.grnItems.isNotEmpty)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 32,
                    dataRowMaxHeight: 32,
                    columnSpacing: 16,
                    columns: [
                      DataColumn(label: Text(l.compReportTableColCode, style: const TextStyle(fontSize: 11))),
                      DataColumn(label: Text(l.compReportTableColItem, style: const TextStyle(fontSize: 11))),
                      DataColumn(label: Text(l.compReportTableColInvoiced, style: const TextStyle(fontSize: 11))),
                      DataColumn(label: Text(l.compReportTableColAccepted, style: const TextStyle(fontSize: 11))),
                      DataColumn(label: Text(l.compReportTableColShortage, style: const TextStyle(fontSize: 11))),
                      DataColumn(label: Text(l.compReportTableColDamaged, style: const TextStyle(fontSize: 11))),
                    ],
                    rows: wh.grnItems.map((item) {
                      final rowSummary = '${item.itemCode} | ${item.itemName} | Invoiced: ${item.invoicedQty} | Accepted: ${item.acceptedQty} | Shortage: ${item.shortageQty} | Damaged: ${item.damagedQty}';
                      return DataRow(cells: [
                        DataCell(CopyableTableCell(
                          value: item.itemCode,
                          rowSummary: rowSummary,
                          child: Text(item.itemCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        )),
                        DataCell(CopyableTableCell(
                          value: item.itemName,
                          rowSummary: rowSummary,
                          child: Text(item.itemName, style: const TextStyle(fontSize: 11)),
                        )),
                        DataCell(CopyableTableCell(
                          value: item.invoicedQty.toString(),
                          rowSummary: rowSummary,
                          child: Text(item.invoicedQty.toString(), style: const TextStyle(fontSize: 11)),
                        )),
                        DataCell(CopyableTableCell(
                          value: item.acceptedQty.toString(),
                          rowSummary: rowSummary,
                          child: Text(item.acceptedQty.toString(), style: const TextStyle(fontSize: 11)),
                        )),
                        DataCell(CopyableTableCell(
                          value: item.shortageQty.toString(),
                          rowSummary: rowSummary,
                          child: Text(item.shortageQty.toString(), style: const TextStyle(fontSize: 11)),
                        )),
                        DataCell(CopyableTableCell(
                          value: item.damagedQty.toString(),
                          rowSummary: rowSummary,
                          child: Text(item.damagedQty.toString(), style: const TextStyle(fontSize: 11)),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}
