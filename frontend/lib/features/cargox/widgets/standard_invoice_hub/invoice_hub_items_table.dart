import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../models/cargox_model.dart';

/// Parsed invoice line items table, HS codes, unit prices, amounts, weights,
/// and supplier/buyer commercial metadata.
class InvoiceHubItemsTable extends StatelessWidget {
  final StandardInvoicePayloadModel? supplierData;

  const InvoiceHubItemsTable({
    super.key,
    required this.supplierData,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (supplierData == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.file_copy_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              l10n.standardInvoiceNoExtractedData,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.standardInvoiceNoExtractedDataSub,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final p = supplierData!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.standardInvoiceDetailsHeader(p.invoiceNumber ?? p.invoiceType, p.invoiceDate ?? 'N/A'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                ),
              ),
              Chip(
                label: Text('${p.totalAmount.toStringAsFixed(2)} ${p.currencyCode}'),
                backgroundColor: AppTheme.emerald.withValues(alpha: 0.15),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInfoCard(l10n.standardInvoiceSellerCardTitle, [
                  l10n.sellerCompanyLabel(p.sellerName ?? 'N/A'),
                  l10n.sellerTaxIdLabel(p.sellerTaxId ?? 'N/A'),
                  '${isAr ? "كود المدينة الدولي:" : "City Code (UN/LOCODE):"} ${p.sellerCityCode ?? "N/A"}',
                  l10n.sellerCountryLabel(p.sellerCountryCode ?? 'N/A'),
                  l10n.sellerAddressLabel(p.sellerAddress ?? 'N/A'),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(l10n.standardInvoiceBuyerCardTitle, [
                  l10n.buyerCompanyLabel(p.buyerName ?? 'N/A'),
                  l10n.buyerTaxIdLabel(p.buyerTaxId ?? 'N/A'),
                  l10n.buyerAcidNumberLabel(p.acidNumber ?? 'N/A'),
                  l10n.buyerIncotermAndCurrencyLabel(p.incoterm ?? 'N/A', p.currencyCode),
                  '${isAr ? "ميناء الشحن:" : "Origin Port (POL):"} ${p.originPort ?? "N/A"}',
                  '${isAr ? "ميناء الوصول:" : "Destination Port (POD):"} ${p.destinationPort ?? "N/A"}',
                ]),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            l10n.standardInvoiceExtractedItemsHeader,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildItemsTable(context, p.items),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<String> lines) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(l, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(BuildContext context, List<StandardInvoiceLineItemModel> items) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        columns: [
          const DataColumn(label: Text('#')),
          DataColumn(label: Text(l10n.colProductCode)),
          DataColumn(label: Text(l10n.colHsCode)),
          DataColumn(label: Text(l10n.colDescription)),
          DataColumn(label: Text(l10n.colQuantity)),
          DataColumn(label: Text(l10n.colUnit)),
          DataColumn(label: Text(l10n.colUnitPrice)),
          DataColumn(label: Text(l10n.colTotalAmount)),
          DataColumn(label: Text(l10n.colGrossWeight)),
          DataColumn(label: Text(l10n.fieldNetWeight)),
          DataColumn(label: Text(l10n.weightUnitFieldLabel)),
        ],
        rows: items.map((item) {
          final rowSummary =
              '${item.index}. ${item.productCode ?? ""} | ${item.hsCode} | ${item.description} | ${item.quantity} ${item.qtyUnit} @ ${item.unitPrice.toStringAsFixed(2)} = ${item.totalAmount.toStringAsFixed(2)} | Gross: ${item.grossWeightKg} | Net: ${item.netWeightKg} ${item.weightUnit}';
          return DataRow(
            cells: [
              DataCell(CopyableTableCell(value: '${item.index}', rowSummary: rowSummary, child: Text('${item.index}'))),
              DataCell(CopyableTableCell(value: item.productCode ?? '—', rowSummary: rowSummary, child: Text(item.productCode ?? '—'))),
              DataCell(CopyableTableCell(
                value: item.hsCode,
                rowSummary: rowSummary,
                child: LtrText(item.hsCode, style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
              DataCell(CopyableTableCell(value: item.description, rowSummary: rowSummary, child: Text(item.description))),
              DataCell(CopyableTableCell(value: '${item.quantity}', rowSummary: rowSummary, child: Text('${item.quantity}'))),
              DataCell(CopyableTableCell(value: item.qtyUnit, rowSummary: rowSummary, child: Text(item.qtyUnit))),
              DataCell(CopyableTableCell(value: item.unitPrice.toStringAsFixed(2), rowSummary: rowSummary, child: Text(item.unitPrice.toStringAsFixed(2)))),
              DataCell(CopyableTableCell(
                value: item.totalAmount.toStringAsFixed(2),
                rowSummary: rowSummary,
                child: Text(
                  item.totalAmount.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
                ),
              )),
              DataCell(CopyableTableCell(value: '${item.grossWeightKg}', rowSummary: rowSummary, child: Text('${item.grossWeightKg}'))),
              DataCell(CopyableTableCell(value: '${item.netWeightKg}', rowSummary: rowSummary, child: Text('${item.netWeightKg}'))),
              DataCell(CopyableTableCell(value: item.weightUnit, rowSummary: rowSummary, child: Text(item.weightUnit))),
            ],
          );
        }).toList(),
      ),
    );
  }
}
