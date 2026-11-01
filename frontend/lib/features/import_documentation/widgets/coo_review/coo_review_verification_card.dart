import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/system_messages/coded_item_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../extraction_match_status_chip.dart';
import '../idoc_ui_b.dart';
import 'coo_review_actions_bar.dart';
import 'coo_review_localizer.dart';
import 'coo_review_service.dart';

class CooReviewVerificationCard extends StatelessWidget {
  final int? selectedImportFileId;
  final Map<String, dynamic>? comparisonResult;
  final Map<String, dynamic>? activeDraftTemplate;
  final String certType;
  final String? activeAcidNumber;
  final String? activeExemptionNotes;
  final TextEditingController overrideReasonCtrl;
  final bool isLoading;
  final bool isSavingDraft;
  final bool isCertifying;
  final VoidCallback onBackToStep1;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onCertify;
  final VoidCallback? onSaveWithJustification;
  final VoidCallback? onSaveDraftJustification;
  final VoidCallback onReturnToEdit;
  final VoidCallback onOverrideReasonChanged;

  const CooReviewVerificationCard({
    super.key,
    required this.selectedImportFileId,
    required this.comparisonResult,
    required this.activeDraftTemplate,
    required this.certType,
    required this.activeAcidNumber,
    required this.activeExemptionNotes,
    required this.overrideReasonCtrl,
    required this.isLoading,
    required this.isSavingDraft,
    required this.isCertifying,
    required this.onBackToStep1,
    required this.onSaveDraft,
    required this.onCertify,
    required this.onSaveWithJustification,
    required this.onSaveDraftJustification,
    required this.onReturnToEdit,
    required this.onOverrideReasonChanged,
  });

  @override
  Widget build(BuildContext context) {
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
                context.l10n.cooSelectFileToViewMatrix,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              IdocBUi.fit(
                AppButton(
                  label: context.l10n.cooBackToSelectFile,
                  onPressed: onBackToStep1,
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
                context.l10n.cooRunComparisonPreviousStep,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              IdocBUi.fit(
                AppButton(
                  label: context.l10n.cooBackToRunComparison,
                  onPressed: onBackToStep1,
                  icon: Icons.arrow_back,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final matrix = CodedItemText.localizeRows(
      comparisonResult!['comparison_matrix'] as List<dynamic>?,
      context.l10n,
    );
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
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasCritical
                          ? Icons.error
                          : (hasDisc ? Icons.warning : Icons.check_circle),
                      color: hasCritical
                          ? AppTheme.crimson
                          : (hasDisc ? AppTheme.orange : AppTheme.emerald),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      hasCritical
                          ? context.l10n.cooCriticalMismatchAlert
                          : (hasDisc
                              ? context.l10n.cooMinorDiscrepancyAlert
                              : context.l10n.cooPerfectMatchSuccess),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                CooReviewMatrixActionsBar(
                  onExportPdf: () => CooReviewService.exportMatrixPdf(
                    context: context,
                    activeDraftTemplate: activeDraftTemplate,
                    certType: certType,
                    activeAcidNumber: activeAcidNumber,
                    activeExemptionNotes: activeExemptionNotes,
                  ),
                  onExportExcel: () => CooReviewService.exportMatrixExcel(
                    context: context,
                    activeDraftTemplate: activeDraftTemplate,
                    certType: certType,
                    activeAcidNumber: activeAcidNumber,
                  ),
                  onSaveDraft: isLoading ? null : onSaveDraft,
                  onCertify: isLoading ? null : onCertify,
                  isSavingDraft: isSavingDraft,
                  isCertifying: isCertifying,
                ),
              ],
            ),
            const Divider(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(context.l10n.cooMatrixColField)),
                  DataColumn(label: Text(context.l10n.cooMatrixColSystemValue)),
                  DataColumn(label: Text(context.l10n.cooMatrixColDraftValue)),
                  DataColumn(label: Text(context.l10n.cooMatrixColStatus)),
                  DataColumn(label: Text(context.l10n.cooMatrixColDetails)),
                ],
                rows: matrix.map((m) {
                  final fieldKey = m['field']?.toString() ?? '';
                  final fieldLabel = CooReviewLocalizer.getFieldLabel(
                    fieldKey,
                    m['field_label_ar']?.toString(),
                    context.l10n,
                  );
                  final sysVal = m['system_value']?.toString() ?? '—';
                  final draftVal = m['draft_value']?.toString() ?? '—';
                  final matchStatus = m['match_status']?.toString() ?? '';
                  final details = m['details']?.toString() ?? '';
                  final rowSummary = '$fieldLabel\t$sysVal\t$draftVal\t$matchStatus\t$details';

                  return DataRow(cells: [
                    DataCell(CopyableTableCell(
                      value: fieldLabel,
                      rowSummary: rowSummary,
                      child: Text(fieldLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                    )),
                    DataCell(CopyableTableCell(
                      value: sysVal,
                      rowSummary: rowSummary,
                      child: Text(sysVal),
                    )),
                    DataCell(CopyableTableCell(
                      value: draftVal,
                      rowSummary: rowSummary,
                      child: Text(draftVal),
                    )),
                    DataCell(CopyableTableCell(
                      value: matchStatus,
                      rowSummary: rowSummary,
                      child: ExtractionMatchStatusChip(
                        matchStatus: matchStatus,
                        severity: m['severity'],
                      ),
                    )),
                    DataCell(CopyableTableCell(
                      value: details,
                      rowSummary: rowSummary,
                      child: Text(details),
                    )),
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
                            context.l10n.cooOverrideReasonTitle,
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
                      context.l10n.cooOverrideReasonSub,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: overrideReasonCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.l10n.cooOverrideReasonLabel,
                        hintText: context.l10n.cooOverrideReasonHint,
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: AppTheme.white,
                      ),
                      onChanged: (_) => onOverrideReasonChanged(),
                    ),
                    const SizedBox(height: 12),
                    CooReviewJustificationActionsBar(
                      onSaveWithJustification: (isLoading || overrideReasonCtrl.text.trim().isEmpty)
                          ? null
                          : onSaveWithJustification,
                      onSaveDraftJustification: isLoading ? null : onSaveDraftJustification,
                      onReturnToEdit: onReturnToEdit,
                      isCertifying: isCertifying,
                      isSavingDraft: isSavingDraft,
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
