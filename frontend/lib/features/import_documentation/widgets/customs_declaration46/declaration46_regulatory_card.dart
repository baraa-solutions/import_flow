import 'package:flutter/material.dart';

import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/density_provider.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../import_files/models/import_file_model.dart';
import '../idoc_ui_b.dart';

class Declaration46RegulatoryCard extends StatelessWidget {
  final List<Map<String, dynamic>> regulatoryApprovals;
  final ImportFileModel? selectedImportFile;
  final String declaration46No;
  final String submissionDate;

  const Declaration46RegulatoryCard({
    super.key,
    required this.regulatoryApprovals,
    required this.selectedImportFile,
    required this.declaration46No,
    required this.submissionDate,
  });

  String _approvalStatusText(Map<String, dynamic> appr, AppLocalizations l) {
    final raw = (appr['status'] ?? '').toString().trim();
    if (raw.isEmpty) return '-';
    final up = raw.toUpperCase();
    if (up == 'APPROVED' || up == 'FULFILLED') return l.customsDeclStatusFulfilled;
    return raw;
  }

  void _copyApprovalRow(BuildContext context, Map<String, dynamic> appr, AppLocalizations l) {
    final String hsCode = appr['hs_code'] ?? '-';
    final String authorityText = (appr['authority'] != null && appr['authority'].toString().trim().isNotEmpty)
        ? appr['authority'].toString()
        : l.customsDeclDefaultAuthority;
    final String inspectionText = appr['requires_inspection'] == true ? l.customsDeclColInspection : '-';
    final String cooText = appr['requires_coo'] == true ? l.customsDeclColCoo : '-';
    final String noteText = (appr['note'] != null && appr['note'].toString().trim().isNotEmpty)
        ? appr['note'].toString()
        : (appr['requires_inspection'] == true ? l.customsDeclDefaultNote : l.customsDeclVisualInspectionNote);
    final String statusText = _approvalStatusText(appr, l);

    final headers = [
      l.customsDeclColHsCode,
      l.customsDeclColAuthority,
      l.customsDeclColInspection,
      l.customsDeclColCoo,
      l.customsDeclColRequirements,
      l.customsDeclColApprovalStatus,
    ];
    final values = [hsCode, authorityText, inspectionText, cooText, noteText, statusText];
    TableCopyHelper.copyRow(context, values, headers: headers);
  }

  void _copyApprovalTable(BuildContext context, AppLocalizations l) {
    final headers = [
      l.customsDeclColHsCode,
      l.customsDeclColAuthority,
      l.customsDeclColInspection,
      l.customsDeclColCoo,
      l.customsDeclColRequirements,
      l.customsDeclColApprovalStatus,
    ];
    final rows = regulatoryApprovals.map((appr) {
      final String hsCode = appr['hs_code'] ?? '-';
      final String authorityText = (appr['authority'] != null && appr['authority'].toString().trim().isNotEmpty)
          ? appr['authority'].toString()
          : l.customsDeclDefaultAuthority;
      final String inspectionText = appr['requires_inspection'] == true ? l.customsDeclColInspection : '-';
      final String cooText = appr['requires_coo'] == true ? l.customsDeclColCoo : '-';
      final String noteText = (appr['note'] != null && appr['note'].toString().trim().isNotEmpty)
          ? appr['note'].toString()
          : (appr['requires_inspection'] == true ? l.customsDeclDefaultNote : l.customsDeclVisualInspectionNote);
      final String statusText = _approvalStatusText(appr, l);
      return [hsCode, authorityText, inspectionText, cooText, noteText, statusText];
    }).toList();

    TableCopyHelper.copyTable(context, headers, rows);
  }

  Future<void> _exportApprovalsToExcel(BuildContext context, AppLocalizations l) async {
    final fileCode = selectedImportFile?.importFileCode ?? 'DRAFT';

    final headers = [
      l.customsDeclColHsCode,
      l.customsDeclColAuthority,
      l.customsDeclColInspection,
      l.customsDeclColCoo,
      l.customsDeclColRequirements,
      l.customsDeclColApprovalStatus,
    ];
    final rows = regulatoryApprovals.map((appr) {
      final String hsCode = appr['hs_code'] ?? '-';
      final String authorityText = (appr['authority'] != null && appr['authority'].toString().trim().isNotEmpty)
          ? appr['authority'].toString()
          : l.customsDeclDefaultAuthority;
      final String inspectionText = appr['requires_inspection'] == true ? l.customsDeclColInspection : '-';
      final String cooText = appr['requires_coo'] == true ? l.customsDeclColCoo : '-';
      final String noteText = (appr['note'] != null && appr['note'].toString().trim().isNotEmpty)
          ? appr['note'].toString()
          : (appr['requires_inspection'] == true ? l.customsDeclDefaultNote : l.customsDeclVisualInspectionNote);
      final String statusText = _approvalStatusText(appr, l);
      return [hsCode, authorityText, inspectionText, cooText, noteText, statusText];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Customs Regulatory Approvals',
      importFileNameOrCode: fileCode,
    );
  }

  Future<void> _exportApprovalsToPdf(BuildContext context, AppLocalizations l) async {
    final fileCode = selectedImportFile?.importFileCode ?? 'DRAFT';

    final headers = [
      l.customsDeclColHsCode,
      l.customsDeclColAuthority,
      l.customsDeclColInspection,
      l.customsDeclColCoo,
      l.customsDeclColApprovalStatus,
    ];
    final rows = regulatoryApprovals.map((appr) {
      final String hsCode = appr['hs_code'] ?? '-';
      final String authorityText = (appr['authority'] != null && appr['authority'].toString().trim().isNotEmpty)
          ? appr['authority'].toString()
          : l.customsDeclDefaultAuthority;
      final String inspectionText = appr['requires_inspection'] == true ? l.customsDeclColInspection : '-';
      final String cooText = appr['requires_coo'] == true ? l.customsDeclColCoo : '-';
      final String statusText = _approvalStatusText(appr, l);
      return [hsCode, authorityText, inspectionText, cooText, statusText];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Customs Regulatory Approvals',
      importFileNameOrCode: fileCode,
      headerContext: TableExportHeaderContext(
        title: l.customsDeclRegulatoryHeader,
        subtitle: l.customsDeclExportSubtitleWithFile(declaration46No, fileCode),
        metadata: {
          l.customsDeclColDeclarationNo: declaration46No,
          l.customsDeclColFileNumber: fileCode,
          l.customsDeclSubmissionDateLabel.replaceAll('*', '').trim(): submissionDate,
          l.customsDeclColSupplier: selectedImportFile?.supplierName ?? '-',
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IdocBSectionCard(
      icon: Icons.policy_outlined,
      title: l.customsDeclRegulatoryHeader,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              AppButton(
                key: const Key('copyRegulatoryTableTsvBtn'),
                label: l.customsDeclExportTsvButton,
                onPressed: () => _copyApprovalTable(context, l),
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                icon: Icons.copy_all,
              ),
              AppButton(
                key: const Key('exportRegulatoryExcelBtn'),
                label: l.exportExcelApprovalsTooltip,
                onPressed: () => _exportApprovalsToExcel(context, l),
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                icon: Icons.table_chart_outlined,
              ),
              AppButton(
                key: const Key('exportRegulatoryPdfBtn'),
                label: l.exportPdfApprovalsTooltip,
                onPressed: () => _exportApprovalsToPdf(context, l),
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                icon: Icons.picture_as_pdf_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkInputBackground : AppTheme.surfaceAlt),
              columns: [
                DataColumn(label: Text(l.customsDeclColHsCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(l.customsDeclColAuthority, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(l.customsDeclColInspection, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(l.customsDeclColCoo, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(l.customsDeclColRequirements, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(l.customsDeclColApprovalStatus, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text(l.customsDeclColActions, style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: regulatoryApprovals.map((appr) {
                final String hsCode = appr['hs_code'] ?? '-';
                final String authorityText = (appr['authority'] != null && appr['authority'].toString().trim().isNotEmpty)
                    ? appr['authority'].toString()
                    : l.customsDeclDefaultAuthority;
                final String inspectionText = appr['requires_inspection'] == true ? l.customsDeclColInspection : '-';
                final String cooText = appr['requires_coo'] == true ? l.customsDeclColCoo : '-';
                final String noteText = (appr['note'] != null && appr['note'].toString().trim().isNotEmpty)
                    ? appr['note'].toString()
                    : (appr['requires_inspection'] == true ? l.customsDeclDefaultNote : l.customsDeclVisualInspectionNote);
                final String statusText = _approvalStatusText(appr, l);
                final String rowSummary = '$hsCode\t$authorityText\t$inspectionText\t$cooText\t$noteText\t$statusText';

                return DataRow(
                  cells: [
                    DataCell(
                      CopyableTableCell(
                        value: hsCode,
                        rowSummary: rowSummary,
                        child: Text(
                          hsCode,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: authorityText,
                        rowSummary: rowSummary,
                        child: Text(
                          authorityText,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextPrimary : null,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: inspectionText,
                        rowSummary: rowSummary,
                        child: Icon(
                          appr['requires_inspection'] == true ? Icons.check_circle : Icons.remove_circle_outline,
                          color: appr['requires_inspection'] == true ? AppTheme.warningForeground : AppTheme.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: cooText,
                        rowSummary: rowSummary,
                        child: Icon(
                          appr['requires_coo'] == true ? Icons.check_circle : Icons.remove_circle_outline,
                          color: appr['requires_coo'] == true ? AppTheme.flatEmerald : AppTheme.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: noteText,
                        rowSummary: rowSummary,
                        child: Text(
                          noteText,
                          style: TextStyle(
                            fontSize: DisplayDensityMode.clampFontSize(12.0),
                            color: isDark ? AppTheme.darkTextPrimary : null,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: statusText,
                        rowSummary: rowSummary,
                        child: IdocBStatusChip(label: statusText, severity: AppSeverity.success),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        key: Key('copyApprovalRowBtn_$hsCode'),
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        tooltip: l.copyApprovalRowSuccess,
                        color: isDark ? AppTheme.darkHyperlink : AppTheme.wcagCobalt,
                        onPressed: () => _copyApprovalRow(context, appr, l),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
