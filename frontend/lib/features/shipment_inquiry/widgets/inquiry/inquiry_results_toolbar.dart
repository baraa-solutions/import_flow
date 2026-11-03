import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// Layer 2 toolbar showing total count and export actions for Shipment Inquiry
class InquiryResultsToolbar extends StatelessWidget {
  final int totalCount;
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;
  final VoidCallback onExportTsv;
  final VoidCallback onCopyDossier;

  const InquiryResultsToolbar({
    super.key,
    required this.totalCount,
    required this.onExportPdf,
    required this.onExportExcel,
    required this.onExportTsv,
    required this.onCopyDossier,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.table_view_rounded, size: 20, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Text(
                l.inqResultsTableTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l.inqShowingMatchingCount(totalCount),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                ),
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppTheme.crimson),
                label: Text(l.inqExportPdfBtn, style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: onExportPdf,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.table_chart_outlined, size: 16, color: AppTheme.emerald),
                label: Text(l.inqExportExcelBtn, style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: onExportExcel,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_present_outlined, size: 16, color: AppTheme.cobalt),
                label: Text(l.inqExportTsvBtn, style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: onExportTsv,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy_all_outlined, size: 18, color: AppTheme.charcoal),
                tooltip: l.inqCopyDossierTooltip,
                onPressed: onCopyDossier,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
