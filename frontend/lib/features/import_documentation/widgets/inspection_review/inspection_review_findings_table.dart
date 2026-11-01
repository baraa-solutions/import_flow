import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/system_messages/coded_item_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../extraction_match_status_chip.dart';
import '../idoc_ui_b.dart';
import 'inspection_review_actions_bar.dart';
import 'inspection_review_controllers.dart';

class InspectionReviewFindingsTable extends StatelessWidget {
  final int? selectedImportFileId;
  final Map<String, dynamic>? comparisonResult;
  final InspectionReviewControllers controllers;
  final VoidCallback onReturnToStep1;
  final VoidCallback onExportTsv;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onCopyDossier;
  final VoidCallback onSaveReview;

  const InspectionReviewFindingsTable({
    super.key,
    required this.selectedImportFileId,
    required this.comparisonResult,
    required this.controllers,
    required this.onReturnToStep1,
    required this.onExportTsv,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onCopyDossier,
    required this.onSaveReview,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (selectedImportFileId == null) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const Icon(Icons.folder_off, size: 48, color: AppTheme.orange),
              const SizedBox(height: 12),
              Text(
                '⚠️ ${l10n.mustSelectFileForMatrixWarning}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              IdocBUi.fit(
                AppButton(
                  label: l10n.returnToSelectFileBtn,
                  onPressed: onReturnToStep1,
                  icon: Icons.arrow_back,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (comparisonResult == null) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const Icon(Icons.compare_arrows, size: 48, color: AppTheme.cobalt),
              const SizedBox(height: 12),
              Text(
                l10n.pleaseRunComparisonPrompt,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              IdocBUi.fit(
                AppButton(
                  label: l10n.returnToRunComparisonBtn,
                  onPressed: onReturnToStep1,
                  icon: Icons.arrow_back,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final rawMatrix = comparisonResult!['comparison_matrix'] as List<dynamic>?;
    final matrix = CodedItemText.localizeRows(rawMatrix, l10n);
    final hasCritical = comparisonResult!['has_critical_mismatch'] as bool? ?? false;
    final hasDisc = comparisonResult!['has_discrepancies'] as bool? ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InspectionReviewActionsBar(
              hasCritical: hasCritical,
              hasDisc: hasDisc,
              onExportTsv: onExportTsv,
              onExportExcel: onExportExcel,
              onExportPdf: onExportPdf,
              onCopyDossier: onCopyDossier,
              onSaveReview: onSaveReview,
            ),
            const Divider(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(l10n.colInspField)),
                  DataColumn(label: Text(l10n.colInspSystemValue)),
                  DataColumn(label: Text(l10n.colInspDraftValue)),
                  DataColumn(label: Text(l10n.colInspMatchStatus)),
                  DataColumn(label: Text(l10n.colInspDetails)),
                ],
                rows: matrix.map((m) {
                  final fieldLabel = m['field_label_ar']?.toString() ?? m['field']?.toString() ?? '';
                  final sysVal = m['system_value']?.toString() ?? '—';
                  final draftVal = m['draft_value']?.toString() ?? '—';
                  final matchStatus = m['match_status']?.toString() ?? '';
                  final details = m['details']?.toString() ?? '';
                  final rowSummary = '$fieldLabel | $sysVal vs $draftVal | $matchStatus | $details';

                  return DataRow(cells: [
                    DataCell(
                      CopyableTableCell(
                        value: fieldLabel,
                        rowSummary: rowSummary,
                        child: Text(fieldLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: sysVal,
                        rowSummary: rowSummary,
                        child: Text(sysVal),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: draftVal,
                        rowSummary: rowSummary,
                        child: Text(draftVal),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: matchStatus,
                        rowSummary: rowSummary,
                        child: ExtractionMatchStatusChip(
                          matchStatus: matchStatus,
                          severity: m['severity'],
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: details,
                        rowSummary: rowSummary,
                        child: Text(details),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
            if (hasDisc || hasCritical) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warningBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.orange, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gavel, color: AppTheme.warningForeground, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.inspOverrideReasonBoxTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.warningForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.inspOverrideReasonBoxDesc,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: controllers.overrideReasonCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: l10n.inspOverrideReasonFieldLabel,
                        hintText: l10n.inspOverrideReasonFieldHint,
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: AppTheme.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IdocBUi.fit(
                          AppButton(
                            label: l10n.approveAndSaveWithReasonBtn,
                            onPressed: onSaveReview,
                            variant: AppButtonVariant.success,
                            icon: Icons.check_circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IdocBUi.fit(
                          AppButton(
                            label: l10n.returnToEditAndContactSupplierBtn,
                            onPressed: onReturnToStep1,
                            variant: AppButtonVariant.secondary,
                            icon: Icons.edit_note,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
