import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

/// Extracted invoice line items table with copyable cells.
class SmartExtractorInvoiceItemsTable extends StatelessWidget {
  final List<dynamic> invoiceItems;

  const SmartExtractorInvoiceItemsTable({
    super.key,
    required this.invoiceItems,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.table_chart_outlined,
                    color: AppTheme.charcoal, size: 20),
                const SizedBox(width: 8),
                Text(
                  l.smartExtractorItemsTableTitle(invoiceItems.length),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (invoiceItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text(l.smartExtractorNoItemsFound)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                          AppTheme.surfaceAltOf(context)),
                      columnSpacing: 16,
                      columns: [
                        const DataColumn(label: Text('#')),
                        DataColumn(
                            label: Text(isArabic ? 'الكود' : 'Item Code')),
                        DataColumn(
                            label: Text(l.smartExtractorColItemDescription)),
                        DataColumn(
                            label: Text(isArabic ? 'البند الجمركي' : 'HS Code')),
                        DataColumn(label: Text(l.smartExtractorColQuantity)),
                        DataColumn(label: Text(l.smartExtractorColUnit)),
                        DataColumn(label: Text(l.smartExtractorColUnitPrice)),
                        DataColumn(label: Text(l.smartExtractorColTotalPrice)),
                        DataColumn(
                            label: Text(
                                isArabic ? 'بلد المنشأ' : 'Country of Origin')),
                      ],
                      rows: List.generate(invoiceItems.length, (idx) {
                        final itm = invoiceItems[idx] as Map<String, dynamic>;
                        final idxStr = '${idx + 1}';
                        final code = '${itm['item_code'] ?? '-'}';
                        final desc = '${itm['description'] ?? '-'}';
                        final hs = '${itm['hs_code'] ?? '-'}';
                        final qty = '${itm['quantity'] ?? 0}';
                        final uom =
                            '${itm['unit_of_measure'] ?? itm['unit'] ?? 'PCS'}';
                        final uPrice = '${itm['unit_price'] ?? 0}';
                        final tPrice = '${itm['total_price'] ?? 0}';
                        final originItem = '${itm['country_of_origin'] ?? '-'}';
                        final rowSummary =
                            '$idxStr\t$code\t$desc\t$hs\t$qty\t$uom\t$uPrice\t$tPrice\t$originItem';

                        return DataRow(cells: [
                          DataCell(
                            CopyableTableCell(
                              value: idxStr,
                              rowSummary: rowSummary,
                              child: Text(idxStr),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: code,
                              rowSummary: rowSummary,
                              child: SizedBox(
                                width: 110,
                                child: Text(
                                  code,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: desc,
                              rowSummary: rowSummary,
                              child: SizedBox(
                                width: 240,
                                child:
                                    Text(desc, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: hs,
                              rowSummary: rowSummary,
                              child: SizedBox(
                                width: 95,
                                child: Text(
                                  hs,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: qty,
                              rowSummary: rowSummary,
                              child: Text(qty),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: uom,
                              rowSummary: rowSummary,
                              child: Text(uom),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: uPrice,
                              rowSummary: rowSummary,
                              child: Text(uPrice),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: tPrice,
                              rowSummary: rowSummary,
                              child: Text(
                                tPrice,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: originItem,
                              rowSummary: rowSummary,
                              child: SizedBox(
                                width: 75,
                                child: Text(originItem,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                        ]);
                      }),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
