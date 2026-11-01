import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../models/cargox_model.dart';

/// Preview result area displaying invoices summary and parsed line items.
class InvoiceHubPreviewResultCard extends StatelessWidget {
  final ExtractionResponseModel response;

  const InvoiceHubPreviewResultCard({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F7),
              borderRadius: const BorderRadiusDirectional.only(topStart: Radius.circular(10), topEnd: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_chart, size: 16, color: AppTheme.charcoal),
                const SizedBox(width: 8),
                Text(
                  l10n.cargoxLiveItemsPreviewHeader,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                ),
              ],
            ),
          ),
          for (final result in response.results) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l10n.cargoxLivePreviewInvoiceBadge(result.invoiceNumber ?? 'Default'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.cargoxLivePreviewTotalValue(result.payload.subtotal.toStringAsFixed(2), result.payload.currencyCode),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.cargoxLivePreviewGrossNet(
                          result.payload.grossWeight.toStringAsFixed(1),
                          result.payload.netWeight.toStringAsFixed(1),
                          result.payload.weightUnit,
                        ),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 32,
                      dataRowMinHeight: 30,
                      dataRowMaxHeight: 36,
                      columnSpacing: 16,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9F9)),
                      columns: [
                        const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(l10n.hsCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(l10n.standardInvoiceManufacturer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(l10n.colDescription, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(l10n.colQuantity, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(l10n.colUnitPrice, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(l10n.colTotalAmount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(l10n.colGrossWeight, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text(l10n.standardInvoiceWeightNet, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      ],
                      rows: result.payload.items.map((item) {
                        final rowSummary =
                            '${item.index}. ${item.hsCode} | ${item.description} | ${item.quantity} ${item.qtyUnit} @ ${item.unitPrice.toStringAsFixed(4)} = ${item.totalAmount.toStringAsFixed(2)} | Gross: ${item.grossWeightKg} | Net: ${item.netWeightKg}';
                        return DataRow(
                          cells: [
                            DataCell(CopyableTableCell(value: '${item.index}', rowSummary: rowSummary, child: Text('${item.index}', style: const TextStyle(fontSize: 11)))),
                            DataCell(CopyableTableCell(
                              value: item.hsCode,
                              rowSummary: rowSummary,
                              child: LtrText(item.hsCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            )),
                            DataCell(CopyableTableCell(value: item.manufacturer ?? '—', rowSummary: rowSummary, child: Text(item.manufacturer ?? '—', style: const TextStyle(fontSize: 11)))),
                            DataCell(CopyableTableCell(value: item.description, rowSummary: rowSummary, child: Text(item.description, style: const TextStyle(fontSize: 11)))),
                            DataCell(CopyableTableCell(value: '${item.quantity} ${item.qtyUnit}', rowSummary: rowSummary, child: Text('${item.quantity} ${item.qtyUnit}', style: const TextStyle(fontSize: 11)))),
                            DataCell(CopyableTableCell(value: item.unitPrice.toStringAsFixed(4), rowSummary: rowSummary, child: Text(item.unitPrice.toStringAsFixed(4), style: const TextStyle(fontSize: 11)))),
                            DataCell(CopyableTableCell(
                              value: item.totalAmount.toStringAsFixed(2),
                              rowSummary: rowSummary,
                              child: Text(
                                item.totalAmount.toStringAsFixed(2),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 11),
                              ),
                            )),
                            DataCell(CopyableTableCell(value: '${item.grossWeightKg} ${result.payload.weightUnit}', rowSummary: rowSummary, child: Text('${item.grossWeightKg} ${result.payload.weightUnit}', style: const TextStyle(fontSize: 11)))),
                            DataCell(CopyableTableCell(value: '${item.netWeightKg} ${result.payload.weightUnit}', rowSummary: rowSummary, child: Text('${item.netWeightKg} ${result.payload.weightUnit}', style: const TextStyle(fontSize: 11)))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
