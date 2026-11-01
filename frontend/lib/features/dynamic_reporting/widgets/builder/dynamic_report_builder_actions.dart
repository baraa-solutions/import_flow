import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/services/master_data_export_service.dart';
import 'package:frontend/core/widgets/widgets.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/dynamic_reporting/models/dynamic_report_models.dart';
import 'dynamic_report_builder_constants.dart';
import 'dynamic_report_cell_resolver.dart';

/// Action buttons toolbar and export/clipboard dispatchers
/// for ImportFlow Dynamic Report Builder.
class DynamicReportBuilderActions extends StatelessWidget {
  final int filteredCount;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;
  final VoidCallback onCopyTsv;
  final VoidCallback? onCustomizeColumns;
  final int? activeColumnCount;
  final int? masterColumnCount;
  final ReportTemplateMode? templateMode;

  const DynamicReportBuilderActions({
    super.key,
    required this.filteredCount,
    required this.onExportCsv,
    required this.onExportPdf,
    required this.onCopyTsv,
    this.onCustomizeColumns,
    this.activeColumnCount,
    this.masterColumnCount,
    this.templateMode,
  });

  /// Executes Excel export of the current filtered report dataset.
  static Future<void> exportToExcel({
    required BuildContext context,
    required WidgetRef ref,
    required List<ImportFileModel> files,
    required List<DynamicReportColumn> activeCols,
    required ReportTemplateMode templateMode,
    required DateTime lastUpdatedAt,
  }) async {
    final l = context.l10n;
    final columnLabels = {
      for (var c in activeCols)
        c.id: DynamicReportBuilderConstants.getColumnLabel(context, c.id)
    };
    final timestampStr = DynamicReportBuilderConstants.formatDateTime(lastUpdatedAt);

    await MasterDataExportService.exportDynamicReportToExcel(
      context: context,
      files: files,
      visibleColumnIds: activeCols.map((c) => c.id).toList(),
      columnLabels: columnLabels,
      cellValueGetter: (f, colId) => DynamicReportCellResolver.getCellValue(
        context: context,
        ref: ref,
        file: f,
        colId: colId,
      ),
      templateTitle: DynamicReportBuilderConstants.getTemplateTitle(context, templateMode),
      timestamp: timestampStr,
      dialogTitle: l.dynExportExcelDialogTitle,
      fileNamePrefix: 'Reports_${templateMode.name.toUpperCase()}',
    );
  }

  /// Executes PDF printing/export of the current filtered report dataset.
  static Future<void> exportToPdf({
    required BuildContext context,
    required WidgetRef ref,
    required List<ImportFileModel> files,
    required List<DynamicReportColumn> activeCols,
    required ReportTemplateMode templateMode,
    required DateTime lastUpdatedAt,
  }) async {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final columnLabels = {
      for (var c in activeCols)
        c.id: DynamicReportBuilderConstants.getColumnLabel(context, c.id)
    };
    final timestampStr = DynamicReportBuilderConstants.formatDateTime(lastUpdatedAt);

    await MasterDataExportService.printOrSaveDynamicReportPdf(
      context: context,
      files: files,
      visibleColumnIds: activeCols.map((c) => c.id).toList(),
      columnLabels: columnLabels,
      cellValueGetter: (f, colId) => DynamicReportCellResolver.getCellValue(
        context: context,
        ref: ref,
        file: f,
        colId: colId,
      ),
      templateTitle: DynamicReportBuilderConstants.getTemplateTitle(context, templateMode),
      timestamp: timestampStr,
      isAr: isAr,
      reportTitle: l.dynPdfReportTitle,
      confidentialText: l.dynPdfConfidential,
      dialogTitle: l.dynExportPdfDialogTitle,
      fileNamePrefix: 'Reports_${templateMode.name.toUpperCase()}',
    );
  }

  /// Copies table content as TSV directly to the clipboard.
  static Future<void> copyDataToClipboard({
    required BuildContext context,
    required WidgetRef ref,
    required List<ImportFileModel> files,
    required List<DynamicReportColumn> activeCols,
  }) async {
    final l = context.l10n;
    final headers = activeCols
        .map((c) => DynamicReportBuilderConstants.getColumnLabel(context, c.id))
        .join('\t');

    final rows = files.map((f) {
      return activeCols
          .map((c) => DynamicReportCellResolver.getCellValue(
                context: context,
                ref: ref,
                file: f,
                colId: c.id,
              ).replaceAll('\n', ' / '))
          .join('\t');
    }).join('\n');

    final content = '$headers\n$rows';
    await CopyHelper.copy(
      context,
      content,
      customMessage: l.dynTsvCopiedMsg(files.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (onCustomizeColumns != null)
            AppButton(
              label: templateMode == ReportTemplateMode.custom &&
                      activeColumnCount != null &&
                      masterColumnCount != null
                  ? l.dynCustomizeColumnsBtn(activeColumnCount!, masterColumnCount!)
                  : l.dynCustomizeColumnsGenericBtn,
              icon: Icons.view_column,
              variant: templateMode == ReportTemplateMode.custom
                  ? AppButtonVariant.primary
                  : AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: onCustomizeColumns,
            ),
          AppButton(
            label: l.dynExportExcelBtn(filteredCount),
            icon: Icons.table_chart,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            onPressed: onExportCsv,
          ),
          AppButton(
            label: l.dynExportPdfBtn(filteredCount),
            icon: Icons.picture_as_pdf,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: onExportPdf,
          ),
          AppButton(
            label: l.dynCopyTsvBtn,
            icon: Icons.copy,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onCopyTsv,
          ),
        ],
      ),
    );
  }
}
