import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../models/cargox_model.dart';
import 'invoice_hub_formatters.dart';

/// Details dialog for a customs track displaying the Commercial Invoice
/// and Customs Packing List tables with copy-safe cells.
class CustomsTrackDetailsDialog extends StatelessWidget {
  final CustomsInvoiceTrackModel track;

  const CustomsTrackDetailsDialog({super.key, required this.track});

  static void show(BuildContext context, CustomsInvoiceTrackModel track) {
    showDialog(
      context: context,
      builder: (ctx) => CustomsTrackDetailsDialog(track: track),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    Map<String, dynamic> invData = {};
    if (track.customsInvoiceData is Map) {
      invData = Map<String, dynamic>.from(track.customsInvoiceData as Map);
    } else if (track.customsInvoiceData is List && (track.customsInvoiceData as List).isNotEmpty) {
      invData = Map<String, dynamic>.from((track.customsInvoiceData as List).first as Map);
    }

    final payload = invData.isNotEmpty ? StandardInvoicePayloadModel.fromJson(invData) : null;
    final packData = (track.customsPackingListData is Map) ? Map<String, dynamic>.from(track.customsPackingListData as Map) : <String, dynamic>{};
    final packItems = (packData['items'] as List<dynamic>?) ?? [];

    return DefaultTabController(
      length: 2,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SelectionArea(
          child: Container(
            width: 1000,
            constraints: const BoxConstraints(maxHeight: 750),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long, color: AppTheme.emerald, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${isAr ? "تفاصيل المسار الجمركي:" : "Customs Track Details:"} ${track.trackCode}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                            ),
                            Text(
                              '${isAr ? "الحالة:" : "Status:"} ${resolveInvoiceHubStatusLabel(context, track.status)} | ${isAr ? "النمط:" : "Mode:"} ${track.extractionMode} | ${isAr ? "إجمالي القيمة:" : "Total:"} ${track.customsTotalAmount.toStringAsFixed(2)} USD',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(color: const Color(0xFFF4F6F7), borderRadius: BorderRadius.circular(8)),
                  child: TabBar(
                    labelColor: AppTheme.charcoal,
                    indicatorColor: AppTheme.emerald,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(icon: const Icon(Icons.receipt), text: isAr ? 'الفاتورة التجارية الجمركية' : 'Customs Commercial Invoice'),
                      Tab(icon: const Icon(Icons.inventory_2), text: isAr ? 'قائمة التعبئة الجمركية' : 'Customs Packing List'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: TabBarView(
                    children: [
                      payload != null && payload.items.isNotEmpty
                          ? SingleChildScrollView(
                              child: DataTable(
                                headingRowHeight: 34,
                                dataRowMinHeight: 32,
                                dataRowMaxHeight: 40,
                                columnSpacing: 14,
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9F9)),
                                columns: [
                                  const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'كود البند الجمركي' : 'HS Code', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'المصنع' : 'Manufacturer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'الوصف' : 'Description', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'الكمية' : 'Quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'سعر الوحدة' : 'Unit Price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'الإجمالي' : 'Total Amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'الوزن القائم' : 'Gross Wt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'الوزن الصافي' : 'Net Wt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                ],
                                rows: payload.items.map((i) {
                                  final rowSummary =
                                      '${i.index}. ${i.hsCode} | ${i.manufacturer ?? ""} | ${i.description} | ${i.quantity} ${i.qtyUnit} @ ${i.unitPrice.toStringAsFixed(4)} = ${i.totalAmount.toStringAsFixed(2)} | Gross: ${i.grossWeightKg} | Net: ${i.netWeightKg}';
                                  return DataRow(
                                    cells: [
                                      DataCell(CopyableTableCell(value: '${i.index}', rowSummary: rowSummary, child: Text('${i.index}', style: const TextStyle(fontSize: 11)))),
                                      DataCell(CopyableTableCell(value: i.hsCode, rowSummary: rowSummary, child: LtrText(i.hsCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                                      DataCell(CopyableTableCell(value: i.manufacturer ?? '—', rowSummary: rowSummary, child: Text(i.manufacturer ?? '—', style: const TextStyle(fontSize: 11)))),
                                      DataCell(CopyableTableCell(value: i.description, rowSummary: rowSummary, child: Text(i.description, style: const TextStyle(fontSize: 11)))),
                                      DataCell(CopyableTableCell(value: '${i.quantity} ${i.qtyUnit}', rowSummary: rowSummary, child: Text('${i.quantity} ${i.qtyUnit}', style: const TextStyle(fontSize: 11)))),
                                      DataCell(CopyableTableCell(value: i.unitPrice.toStringAsFixed(4), rowSummary: rowSummary, child: Text(i.unitPrice.toStringAsFixed(4), style: const TextStyle(fontSize: 11)))),
                                      DataCell(CopyableTableCell(
                                        value: i.totalAmount.toStringAsFixed(2),
                                        rowSummary: rowSummary,
                                        child: Text(
                                          i.totalAmount.toStringAsFixed(2),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.emerald),
                                        ),
                                      )),
                                      DataCell(CopyableTableCell(value: '${i.grossWeightKg}', rowSummary: rowSummary, child: Text(i.grossWeightKg.toStringAsFixed(1), style: const TextStyle(fontSize: 11)))),
                                      DataCell(CopyableTableCell(value: '${i.netWeightKg}', rowSummary: rowSummary, child: Text(i.netWeightKg.toStringAsFixed(1), style: const TextStyle(fontSize: 11)))),
                                    ],
                                  );
                                }).toList(),
                              ),
                            )
                          : Center(child: Text(isAr ? 'لا توجد بنود مفصلة بالفاتورة' : 'No line items available')),
                      packItems.isNotEmpty
                          ? SingleChildScrollView(
                              child: DataTable(
                                headingRowHeight: 34,
                                dataRowMinHeight: 32,
                                dataRowMaxHeight: 40,
                                columnSpacing: 14,
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9F9)),
                                columns: [
                                  const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'رقم الطرد' : 'Package No', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'كود التعريفة' : 'HS Code', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'المصنع' : 'Manufacturer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'بيان الصنف' : 'Description', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'الكمية' : 'Quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'الصافي (كجم)' : 'Net (kg)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text(isAr ? 'القائم (كجم)' : 'Gross (kg)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                ],
                                rows: packItems.map((i) {
                                  final idx = packItems.indexOf(i) + 1;
                                  final rowSummary =
                                      '$idx. ${i["package_no"] ?? "PKG $idx"} | ${i["hs_code"] ?? ""} | ${i["manufacturer"] ?? ""} | ${i["description"] ?? ""} | ${i["quantity"] ?? 0} ${i["qty_unit"] ?? "PCS"} | Net: ${i["net_weight_kg"] ?? 0} | Gross: ${i["gross_weight_kg"] ?? 0}';
                                  return DataRow(
                                    cells: [
                                      DataCell(CopyableTableCell(value: '$idx', rowSummary: rowSummary, child: Text('$idx', style: const TextStyle(fontSize: 11)))),
                                      DataCell(CopyableTableCell(value: i['package_no']?.toString() ?? 'PKG $idx', rowSummary: rowSummary, child: Text(i['package_no']?.toString() ?? 'PKG $idx', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                                      DataCell(CopyableTableCell(value: i['hs_code']?.toString() ?? '', rowSummary: rowSummary, child: Text(i['hs_code']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                                      DataCell(CopyableTableCell(value: i['manufacturer']?.toString() ?? '', rowSummary: rowSummary, child: Text(i['manufacturer']?.toString() ?? '', style: const TextStyle(fontSize: 11)))),
                                      DataCell(CopyableTableCell(value: i['description']?.toString() ?? '', rowSummary: rowSummary, child: Text(i['description']?.toString() ?? '', style: const TextStyle(fontSize: 11)))),
                                      DataCell(CopyableTableCell(value: '${i["quantity"] ?? 0} ${i["qty_unit"] ?? "PCS"}', rowSummary: rowSummary, child: Text('${i["quantity"] ?? 0} ${i["qty_unit"] ?? "PCS"}', style: const TextStyle(fontSize: 11)))),
                                      DataCell(CopyableTableCell(value: (i['net_weight_kg'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0', rowSummary: rowSummary, child: Text((i['net_weight_kg'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0', style: const TextStyle(fontSize: 11)))),
                                      DataCell(CopyableTableCell(value: (i['gross_weight_kg'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0', rowSummary: rowSummary, child: Text((i['gross_weight_kg'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0', style: const TextStyle(fontSize: 11)))),
                                    ],
                                  );
                                }).toList(),
                              ),
                            )
                          : Center(child: Text(isAr ? 'لا توجد بيانات لقائمة التعبئة' : 'No packing list items available')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: isAr ? 'إغلاق' : 'Close',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
