import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/cargox_model.dart';

/// Error banner and preview summary chips for dual extraction results
class DualPreviewSummaryPanel extends StatelessWidget {
  final DualExtractionResponseModel previewResult;
  final VoidCallback onCopySummary;

  const DualPreviewSummaryPanel({
    super.key,
    required this.previewResult,
    required this.onCopySummary,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final r = previewResult;
    final invoiceSummary = isAr
        ? '${r.invoiceInvoicesCount} فاتورة · ${r.invoiceTotalLineItems} بند'
        : '${r.invoiceInvoicesCount} invoices · ${r.invoiceTotalLineItems} items';
    final plSummary = isAr
        ? '${r.packingListCount} ملف · ${r.packingListTotalItems} بند'
        : '${r.packingListCount} files · ${r.packingListTotalItems} items';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.dualExtractionPreviewResults,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.emerald),
                tooltip: l.dualExtractionCopySummaryTooltip,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onCopySummary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _previewChip(Icons.receipt_long, l.dualExtractionCommercialInvoice, invoiceSummary, AppTheme.cobalt),
              const SizedBox(width: 12),
              _previewChip(Icons.inventory_2_outlined, l.dualExtractionPackingList, plSummary, AppTheme.emerald),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: color)),
                  Text(value, style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone error banner widget
class DualExtractionErrorBanner extends StatelessWidget {
  final String errorMessage;

  const DualExtractionErrorBanner({
    super.key,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(errorMessage, style: const TextStyle(fontSize: 11, color: Colors.orange))),
        ],
      ),
    );
  }
}
