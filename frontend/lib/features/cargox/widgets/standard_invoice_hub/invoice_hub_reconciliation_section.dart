import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/cargox_model.dart';
import 'invoice_hub_formatters.dart';

/// Matching status against BL/PO, discrepancies highlights, variance indicators,
/// and discrepancy rectification notices for standard invoices.
class InvoiceHubReconciliationSection extends StatelessWidget {
  final StandardInvoiceComparisonResponseModel? comparisonResult;

  const InvoiceHubReconciliationSection({
    super.key,
    required this.comparisonResult,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (comparisonResult == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.compare_arrows, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              l10n.standardInvoiceNoComparisonData,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.standardInvoiceNoComparisonDataSub,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final c = comparisonResult!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildComparisonStatsBanner(context, c),
          const SizedBox(height: 20),
          Text(
            l10n.standardInvoiceCompHeadersSection,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildComparisonTable(context, c.headerComparisons),
          const SizedBox(height: 20),
          Text(
            l10n.standardInvoiceCompFinancialsSection,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildComparisonTable(context, c.financialComparisons),
          const SizedBox(height: 20),
          Text(
            l10n.standardInvoiceCompItemsSection,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildLineItemsComparisonTable(context, c.lineItemComparisons),
          if (c.hasDiscrepancies) ...[
            const SizedBox(height: 24),
            _buildRectificationNoticeSection(context, c),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonStatsBanner(BuildContext context, StandardInvoiceComparisonResponseModel c) {
    final l10n = context.l10n;
    Color bg = AppTheme.emerald.withValues(alpha: 0.1);
    Color border = AppTheme.emerald;
    IconData icon = Icons.check_circle;
    String title = l10n.standardInvoiceMatch100Banner;

    if (c.hasCriticalMismatch) {
      bg = AppTheme.crimson.withValues(alpha: 0.1);
      border = AppTheme.crimson;
      icon = Icons.cancel;
      title = l10n.standardInvoiceCriticalMismatchBanner(c.criticalMismatchesCount);
    } else if (c.hasDiscrepancies) {
      bg = AppTheme.orange.withValues(alpha: 0.1);
      border = AppTheme.orange;
      icon = Icons.warning;
      title = l10n.standardInvoiceDiscrepanciesBanner(c.totalDiscrepanciesCount);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: border, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: border),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context, List<StandardInvoiceComparisonRowModel> rows) {
    final l10n = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        columns: [
          DataColumn(label: Text(l10n.standardInvoiceColComparedField)),
          DataColumn(label: Text(l10n.standardInvoiceColSystemValue)),
          DataColumn(label: Text(l10n.standardInvoiceColSupplierValue)),
          DataColumn(label: Text(l10n.standardInvoiceColMatchStatus)),
          DataColumn(label: Text(l10n.standardInvoiceColDiffAndNotes)),
        ],
        rows: rows.map((r) {
          final label = isAr ? r.fieldLabelAr : r.fieldLabelEn;
          final rowSummary =
              '$label | System: ${r.systemValue ?? "—"} | Supplier: ${r.supplierValue ?? "—"} | Status: ${r.status} | Diff: ${r.difference ?? r.notes ?? "—"}';
          return DataRow(
            cells: [
              DataCell(CopyableTableCell(value: label, rowSummary: rowSummary, child: Text(label))),
              DataCell(CopyableTableCell(
                value: r.systemValue ?? '—',
                rowSummary: rowSummary,
                child: Text(r.systemValue ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
              DataCell(CopyableTableCell(value: r.supplierValue ?? '—', rowSummary: rowSummary, child: Text(r.supplierValue ?? '—'))),
              DataCell(AppStatusBadge.fromStatus(
                status: r.status,
                label: resolveInvoiceHubStatusLabel(context, r.status),
                size: AppStatusBadgeSize.small,
              )),
              DataCell(CopyableTableCell(
                value: r.difference ?? r.notes ?? '—',
                rowSummary: rowSummary,
                child: Text(
                  r.difference ?? r.notes ?? '—',
                  style: TextStyle(color: r.status == 'MATCH' ? Colors.grey : AppTheme.crimson),
                ),
              )),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineItemsComparisonTable(BuildContext context, List<StandardInvoiceLineComparisonRowModel> rows) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        columns: [
          const DataColumn(label: Text('#')),
          DataColumn(label: Text(l10n.colProductCode)),
          DataColumn(label: Text(l10n.standardInvoiceColHsSystem)),
          DataColumn(label: Text(l10n.standardInvoiceColHsSupplier)),
          DataColumn(label: Text(l10n.standardInvoiceColQtySystem)),
          DataColumn(label: Text(l10n.standardInvoiceColQtySupplier)),
          DataColumn(label: Text(l10n.standardInvoiceColPriceSystem)),
          DataColumn(label: Text(l10n.standardInvoiceColPriceSupplier)),
          DataColumn(label: Text(l10n.standardInvoiceColMatchStatus)),
          DataColumn(label: Text(l10n.standardInvoiceColDiffAndNotes)),
        ],
        rows: rows.map((r) {
          final rowSummary =
              '${r.index}. ${r.productCode} | HS Sys: ${r.hsCodeSystem ?? "—"} / Supp: ${r.hsCodeSupplier ?? "—"} | Qty Sys: ${r.qtySystem} / Supp: ${r.qtySupplier} | Price Sys: ${r.unitPriceSystem.toStringAsFixed(2)} / Supp: ${r.unitPriceSupplier.toStringAsFixed(2)} | Status: ${r.status} | Notes: ${r.notes ?? "—"}';
          return DataRow(
            cells: [
              DataCell(CopyableTableCell(value: '${r.index}', rowSummary: rowSummary, child: Text('${r.index}'))),
              DataCell(CopyableTableCell(value: r.productCode, rowSummary: rowSummary, child: Text(r.productCode))),
              DataCell(CopyableTableCell(value: r.hsCodeSystem ?? '—', rowSummary: rowSummary, child: Text(r.hsCodeSystem ?? '—'))),
              DataCell(CopyableTableCell(value: r.hsCodeSupplier ?? '—', rowSummary: rowSummary, child: Text(r.hsCodeSupplier ?? '—'))),
              DataCell(CopyableTableCell(value: '${r.qtySystem}', rowSummary: rowSummary, child: Text('${r.qtySystem}'))),
              DataCell(CopyableTableCell(value: '${r.qtySupplier}', rowSummary: rowSummary, child: Text('${r.qtySupplier}'))),
              DataCell(CopyableTableCell(
                value: r.unitPriceSystem.toStringAsFixed(2),
                rowSummary: rowSummary,
                child: Text(r.unitPriceSystem.toStringAsFixed(2)),
              )),
              DataCell(CopyableTableCell(
                value: r.unitPriceSupplier.toStringAsFixed(2),
                rowSummary: rowSummary,
                child: Text(r.unitPriceSupplier.toStringAsFixed(2)),
              )),
              DataCell(AppStatusBadge.fromStatus(
                status: r.status,
                label: resolveInvoiceHubStatusLabel(context, r.status),
                size: AppStatusBadgeSize.small,
              )),
              DataCell(CopyableTableCell(value: r.notes ?? '—', rowSummary: rowSummary, child: Text(r.notes ?? '—'))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRectificationNoticeSection(BuildContext context, StandardInvoiceComparisonResponseModel c) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.standardInvoiceRectificationSectionTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (c.rectificationNoticeEn != null)
            ListTile(
              title: Text(
                l10n.standardInvoiceRectificationEnTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(c.rectificationNoticeEn!, maxLines: 3, overflow: TextOverflow.ellipsis),
              trailing: AppButton(
                label: l10n.copy,
                icon: Icons.copy,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: () {
                  CopyHelper.copy(
                    context,
                    c.rectificationNoticeEn!,
                    customMessage: l10n.standardInvoiceCopiedToClipboard(l10n.standardInvoiceRectificationEnTitle),
                  );
                },
              ),
            ),
          const Divider(),
          if (c.rectificationNoticeAr != null)
            ListTile(
              title: Text(
                l10n.standardInvoiceRectificationArTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(c.rectificationNoticeAr!, maxLines: 3, overflow: TextOverflow.ellipsis),
              trailing: AppButton(
                label: l10n.copy,
                icon: Icons.copy,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                onPressed: () {
                  CopyHelper.copy(
                    context,
                    c.rectificationNoticeAr!,
                    customMessage: l10n.standardInvoiceCopiedToClipboard(l10n.standardInvoiceRectificationArTitle),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
