import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/system_messages/coded_item_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';
import '../../providers/import_documentation_provider.dart';
import '../idoc_ui_b.dart';
import '../visual_draft_inspection_sheet.dart';

class InspectionReviewDialogs {
  InspectionReviewDialogs._();

  static void showVisualPreviewDialog({
    required BuildContext context,
    required String agency,
    required String certType,
    required String acidNumber,
    required List<String> standards,
    required Map<String, dynamic> template,
    required VoidCallback onRefresh,
    required VoidCallback onApplyData,
  }) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Text(
                  l10n.inspectionVisualPreviewDialogTitle(agency, certType),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppTheme.textMuted),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 860,
          child: SelectionArea(
            child: SingleChildScrollView(
              child: VisualDraftInspectionSheet(
                templateData: template,
                agency: agency,
                certType: certType,
                acidNumber: acidNumber,
                standards: standards,
                onRefresh: onRefresh,
              ),
            ),
          ),
        ),
        actions: [
          IdocBUi.fit(
            AppButton(
              label: l10n.cancelAndClose,
              onPressed: () => Navigator.pop(ctx),
              variant: AppButtonVariant.secondary,
            ),
          ),
          IdocBUi.fit(
            AppButton(
              label: l10n.applyInspectionDraftDataBtn,
              onPressed: () {
                Navigator.pop(ctx);
                onApplyData();
              },
              variant: AppButtonVariant.success,
              icon: Icons.check,
            ),
          ),
        ],
      ),
    );
  }

  static void showDetailsDialog({
    required BuildContext context,
    required InspectionCertificateReviewModel review,
  }) {
    final l10n = context.l10n;
    final overrideReason = review.notes ?? review.draftInputData?['override_reason'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Text(l10n.inspDetailsDialogTitle(review.inspectionReviewCode)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.copy_all, color: AppTheme.cobalt, size: 20),
              tooltip: l10n.copyDossierBtn,
              onPressed: () {
                final summary = '''
${l10n.inspDetailsDialogTitle(review.inspectionReviewCode)}
${l10n.tileInspTypeAndAgency}: ${review.inspectionType} — ${review.inspectionAgency}
${l10n.tileInspCertNoAndStatus}: ${review.certificateNumber} | ${review.status}
${overrideReason.isNotEmpty ? '${l10n.tileInspOverrideReason}: $overrideReason\n' : ''}''';
                CopyHelper.copy(ctx, summary, customMessage: l10n.copiedDossierSuccess);
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 700,
          child: SelectionArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(l10n.tileInspTypeAndAgency),
                    subtitle: Text('${review.inspectionType} — ${review.inspectionAgency}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.copyValue,
                      onPressed: () => CopyHelper.copy(ctx, '${review.inspectionType} — ${review.inspectionAgency}'),
                    ),
                    dense: true,
                  ),
                  ListTile(
                    title: Text(l10n.tileInspCertNoAndStatus),
                    subtitle: Text('${review.certificateNumber} | ${review.status}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l10n.copyValue,
                      onPressed: () => CopyHelper.copy(ctx, '${review.certificateNumber} | ${review.status}'),
                    ),
                    dense: true,
                  ),
                  if (overrideReason.isNotEmpty)
                    ListTile(
                      title: Text(l10n.tileInspOverrideReason),
                      subtitle: Text(
                        overrideReason,
                        style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: l10n.copyValue,
                        onPressed: () => CopyHelper.copy(ctx, overrideReason),
                      ),
                      dense: true,
                    ),
                  if (review.comparisonMatrix.isNotEmpty) ...[
                    const Divider(),
                    Text(l10n.sectionInspDiscrepancyMatrix, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...review.comparisonMatrix.map((m) {
                      final item = m is Map ? CodedItemText.localizeRow(m, l10n) : {};
                      final rowText =
                          '${item['field_label_ar'] ?? item['field']}: [${item['draft_value']}] vs [${item['system_value']}]';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: InkWell(
                          onTap: () => CopyHelper.copy(ctx, rowText),
                          child: Row(
                            children: [
                              Icon(
                                item['match_status'] == 'MATCH' ? Icons.check_circle : Icons.warning,
                                color: item['match_status'] == 'MATCH' ? AppTheme.emerald : AppTheme.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  rowText,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy, size: 14, color: AppTheme.textMuted),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          IdocBUi.fit(
            AppButton(
              label: l10n.cancel,
              onPressed: () => Navigator.of(ctx).pop(),
              variant: AppButtonVariant.secondary,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> confirmDelete({
    required BuildContext context,
    required WidgetRef ref,
    required InspectionCertificateReviewModel review,
  }) async {
    final l10n = context.l10n;
    final confirmed = await AppConfirmDialog.showDelete(
      context,
      title: l10n.confirmDeleteInspSessionTitle,
      message: l10n.confirmDeleteInspSessionContent(review.inspectionReviewCode, review.certificateNumber),
    );
    if (confirmed == true) {
      try {
        await ref.read(inspectionReviewsProvider.notifier).deleteInspectionReview(review.inspectionReviewId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, '✔ ', severity: AppSeverity.success),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l10n.deleteInspSessionError(ApiErrorText.of(l10n, e)),
              severity: AppSeverity.danger,
            ),
          );
        }
      }
    }
  }
}
