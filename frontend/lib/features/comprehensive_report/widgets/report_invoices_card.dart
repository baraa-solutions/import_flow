import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/copyable_data_helper.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/comprehensive_dossier_model.dart';
import 'report_card_container.dart';
import 'report_copy_badge.dart';

/// Invoices and purchase orders summary card for the Comprehensive Report.
class ReportInvoicesCard extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;

  const ReportInvoicesCard({
    super.key,
    required this.file,
    this.dossier,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pos = dossier?.purchaseOrders ?? [];
    final invs = file.invoicesData;

    if (pos.isEmpty && invs.isEmpty) {
      return ReportCardContainer(
        title: l.compReportSecInvoices(0),
        icon: Icons.receipt_outlined,
        iconColor: AppTheme.emerald,
        child: Text(l.compReportNoInvoices, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    return ReportCardContainer(
      title: 'الفواتير وأوامر الشراء (${pos.length} PO • ${invs.length} فاتورة)',
      icon: Icons.receipt_outlined,
      iconColor: AppTheme.emerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Linked Purchase Orders
          if (pos.isNotEmpty) ...[
            const Text(
              '📦 أوامر التوريد المعتمدة (Purchase Orders):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 6),
            ...pos.map((po) {
              final poNo = po['po_number']?.toString() ?? 'PO';
              final poRef = po['po_reference']?.toString() ?? '';
              final poFob = (po['total_amount_fob'] as num?)?.toDouble() ?? 0.0;
              final curr = po['currency']?.toString() ?? 'USD';
              final piNo = po['proforma_invoice_number']?.toString();
              final status = po['status']?.toString() ?? 'Approved';

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    ReportCopyBadge(
                      textToCopy: poNo,
                      color: Colors.white,
                      borderColor: Colors.blue.shade300,
                      textColor: const Color(0xFF1E3A8A),
                    ),
                    if (poRef.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(poRef, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                    ],
                    if (piNo != null && piNo.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text('PI: $piNo', style: const TextStyle(fontSize: 10, color: AppTheme.charcoal)),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${poFob.toStringAsFixed(2)} $curr',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
          ],

          // 2. Commercial / Proforma Invoices
          if (invs.isNotEmpty) ...[
            const Text(
              '🧾 الفواتير المرفقة (Invoices):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 6),
            ...invs.map((inv) {
              final rowSummary = '${inv.invoiceNo} | ${inv.invoiceType} | ${inv.amount.toStringAsFixed(2)} ${inv.currency}${inv.date != null ? " | ${inv.date}" : ""}';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: CopyableTableCell(
                  value: inv.invoiceNo,
                  rowSummary: rowSummary,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.teal.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt, size: 16, color: Colors.teal),
                        const SizedBox(width: 8),
                        ReportCopyBadge(
                          textToCopy: inv.invoiceNo,
                          color: Colors.white,
                          borderColor: Colors.teal.shade200,
                          textColor: Colors.teal.shade900,
                        ),
                        const SizedBox(width: 8),
                        Text(inv.invoiceType, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        const Spacer(),
                        Text(
                          '${inv.amount.toStringAsFixed(2)} ${inv.currency}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal, fontSize: 12),
                        ),
                        if (inv.date != null) ...[
                          const SizedBox(width: 8),
                          Text(inv.date!, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
