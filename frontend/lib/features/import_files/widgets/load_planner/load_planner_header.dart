// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/import_file_model.dart';

/// Top header of the Visual Container Load Planner Dialog.
/// Supports responsive layout for Mobile (<768px) and Desktop/Tablet (>=768px),
/// displaying the title, fleet summary pill, and export actions strip.
class LoadPlannerHeader extends StatelessWidget {
  final ImportFileModel file;
  final String fleetSummaryText;
  final int planLength;
  final bool isExportingImage;
  final bool isExportingExcel;
  final bool isExportingPdf;
  final VoidCallback onCopyTable;
  final VoidCallback onSaveImage;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;

  const LoadPlannerHeader({
    super.key,
    required this.file,
    required this.fleetSummaryText,
    required this.planLength,
    required this.isExportingImage,
    required this.isExportingExcel,
    required this.isExportingPdf,
    required this.onCopyTable,
    required this.onSaveImage,
    required this.onExportExcel,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);
    final screenW = MediaQuery.of(context).size.width;

    if (screenW < 768) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.view_in_ar, color: AppTheme.cobalt, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l.visualLoadPlannerTitle} — ${file.importFileCode}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildFleetPill(isDark),
              _buildActionButtons(l, isCompact: true),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.view_in_ar, color: AppTheme.cobalt, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${l.visualLoadPlannerTitle} — ${file.importFileCode}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _buildFleetPill(isDark),
        const SizedBox(width: 10),
        _buildActionButtons(l, isCompact: false),
      ],
    );
  }

  Widget _buildFleetPill(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.blue.shade900.withOpacity(0.3)
            : AppTheme.cobalt.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.blue.shade700 : AppTheme.cobalt,
        ),
      ),
      child: Text(
        '$fleetSummaryText ($planLength)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
        ),
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations l, {required bool isCompact}) {
    final copyTooltip = l.isArabic ? 'نسخ الجدول' : 'Copy Table';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 0. Copy Table (TSV) Action
        IconButton(
          key: const Key('copyTableBtn'),
          tooltip: copyTooltip,
          visualDensity: isCompact ? VisualDensity.compact : null,
          padding: isCompact ? const EdgeInsets.all(4) : null,
          constraints: isCompact ? const BoxConstraints() : null,
          icon: Icon(Icons.copy_outlined,
              color: AppTheme.cobalt, size: isCompact ? 18 : 20),
          onPressed: onCopyTable,
        ),
        SizedBox(width: isCompact ? 4 : 4),

        // 1. Save Image (PNG) Action
        IconButton(
          key: const Key('saveImageBtn'),
          tooltip: l.saveContainerImageTooltip,
          visualDensity: isCompact ? VisualDensity.compact : null,
          padding: isCompact ? const EdgeInsets.all(4) : null,
          constraints: isCompact ? const BoxConstraints() : null,
          icon: isExportingImage
              ? SizedBox(
                  width: isCompact ? 16 : 18,
                  height: isCompact ? 16 : 18,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.image_outlined,
                  color: AppTheme.cobalt, size: isCompact ? 18 : 20),
          onPressed: isExportingImage ? null : onSaveImage,
        ),
        SizedBox(width: isCompact ? 4 : 4),

        // 2. Export Excel (.xlsx) Action
        IconButton(
          key: const Key('exportExcelBtn'),
          tooltip: l.exportContainerExcelTooltip,
          visualDensity: isCompact ? VisualDensity.compact : null,
          padding: isCompact ? const EdgeInsets.all(4) : null,
          constraints: isCompact ? const BoxConstraints() : null,
          icon: isExportingExcel
              ? SizedBox(
                  width: isCompact ? 16 : 18,
                  height: isCompact ? 16 : 18,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.emerald,
                  ),
                )
              : Icon(Icons.table_chart_outlined,
                  color: AppTheme.emerald, size: isCompact ? 18 : 20),
          onPressed: isExportingExcel ? null : onExportExcel,
        ),
        SizedBox(width: isCompact ? 4 : 4),

        // 3. Export PDF Action
        IconButton(
          key: const Key('exportPdfBtn'),
          tooltip: l.exportContainerPdfTooltip,
          visualDensity: isCompact ? VisualDensity.compact : null,
          padding: isCompact ? const EdgeInsets.all(4) : null,
          constraints: isCompact ? const BoxConstraints() : null,
          icon: isExportingPdf
              ? SizedBox(
                  width: isCompact ? 16 : 18,
                  height: isCompact ? 16 : 18,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.crimson,
                  ),
                )
              : Icon(Icons.picture_as_pdf_outlined,
                  color: AppTheme.crimson, size: isCompact ? 18 : 20),
          onPressed: isExportingPdf ? null : onExportPdf,
        ),
      ],
    );
  }
}
