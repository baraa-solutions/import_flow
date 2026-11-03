import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/dynamic_reporting/models/dynamic_report_models.dart';
import 'dynamic_report_builder_constants.dart';
import 'dynamic_report_cell_resolver.dart';

/// Live table preview component for ImportFlow Dynamic Report Builder.
class DynamicReportTableView extends ConsumerWidget {
  final List<ImportFileModel> files;
  final List<DynamicReportColumn> activeColumns;
  final ReportTemplateMode templateMode;
  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;

  const DynamicReportTableView({
    super.key,
    required this.files,
    required this.activeColumns,
    required this.templateMode,
    this.isLoading = false,
    this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    if (isLoading) {
      return const AppLoadingState();
    }

    if (error != null) {
      return AppErrorState(
        error: error!,
        onRetry: onRetry,
      );
    }

    return SelectionArea(
      child: EnterpriseDataTable<ImportFileModel>(
        key: ValueKey('${templateMode.name}_${activeColumns.length}'),
        data: files,
        isScrollable: true,
        showHeaderToolbar: false,
        emptyMessage: l.dynNoMatchingShipments,
        columns: activeColumns.map((col) {
          final isFirstCol = col.id == activeColumns.first.id;
          final isCode = col.id == 'importFileCode' ||
              col.id == 'ecoShipmentNo' ||
              col.id == 'acidNumber' ||
              col.id == 'form4No';
          final isStatus = col.id == 'status' || col.id == 'currentStage';

          return EnterpriseColumn<ImportFileModel>(
            id: col.id,
            title: DynamicReportBuilderConstants.getColumnLabel(context, col.id),
            exportValue: (file) => DynamicReportCellResolver.getCellValue(
              context: context,
              ref: ref,
              file: file,
              colId: col.id,
            ),
            searchValue: (file) => DynamicReportCellResolver.getCellValue(
              context: context,
              ref: ref,
              file: file,
              colId: col.id,
            ),
            cellBuilder: (context, file, index) {
              final textVal = DynamicReportCellResolver.getCellValue(
                context: context,
                ref: ref,
                file: file,
                colId: col.id,
              );
              final rowSummary = DynamicReportCellResolver.buildRowSummary(
                context: context,
                ref: ref,
                file: file,
                cols: activeColumns,
              );

              return CopyableTableCell(
                value: textVal,
                rowSummary: rowSummary,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFirstCol) ...[
                        InkWell(
                          onTap: () => CopyHelper.copy(
                            context,
                            rowSummary,
                            customMessage: l.copiedToClipboardGeneric,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          child: Tooltip(
                            message: l.dynCopyRowTooltip,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.table_rows_rounded,
                                size: 13,
                                color: AppTheme.emerald.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          textVal,
                          style: TextStyle(
                            fontWeight: isCode ? FontWeight.bold : FontWeight.normal,
                            color: isCode
                                ? AppTheme.cobalt
                                : (isStatus ? AppTheme.charcoal : Colors.grey.shade900),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCode && textVal != '-' && textVal.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => CopyHelper.copy(context, textVal),
                          borderRadius: BorderRadius.circular(4),
                          child: Tooltip(
                            message: l.copyValue,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 13,
                                color: AppTheme.cobalt.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
