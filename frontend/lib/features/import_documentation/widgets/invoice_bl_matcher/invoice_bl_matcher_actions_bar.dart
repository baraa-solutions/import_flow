import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/system_messages/coded_item_text.dart';
import '../../../../core/services/file_save_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../idoc_ui.dart';

/// Top execution actions bar for Screen 22: Invoice vs B/L Matcher.
class InvoiceBlMatcherActionsBar extends StatelessWidget {
  final bool isLoading;
  final bool isSavingDraft;
  final int? activeFileId;
  final VoidCallback onRunMatch;
  final VoidCallback onLoadSample;
  final VoidCallback onReset;
  final VoidCallback onSaveDraft;

  const InvoiceBlMatcherActionsBar({
    super.key,
    required this.isLoading,
    required this.isSavingDraft,
    required this.activeFileId,
    required this.onRunMatch,
    required this.onLoadSample,
    required this.onReset,
    required this.onSaveDraft,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IdocUi.fit(AppButton(
          label: l.invoiceBlMatcherExecuteMatchButton,
          icon: Icons.compare_arrows,
          variant: AppButtonVariant.primary,
          isLoading: isLoading,
          onPressed: isLoading ? null : onRunMatch,
        )),
        if (kDebugMode)
          IdocUi.fit(AppButton(
            label: l.invoiceBlMatcherLoadSampleButton,
            icon: Icons.auto_stories,
            variant: AppButtonVariant.secondary,
            onPressed: onLoadSample,
          )),
        IdocUi.fit(AppButton(
          label: l.invoiceBlMatcherResetButton,
          icon: Icons.refresh,
          variant: AppButtonVariant.ghost,
          onPressed: onReset,
        )),
        IdocUi.fit(AppButton(
          label: context.l10n.idocASaveSessionDraftEmoji,
          icon: Icons.save_as_outlined,
          variant: AppButtonVariant.secondary,
          isLoading: isSavingDraft,
          onPressed: (activeFileId == null || isSavingDraft || isLoading) ? null : onSaveDraft,
        )),
      ],
    );
  }
}

/// Footer actions bar for Screen 22: Final approval, Draft save, and Report Export.
class InvoiceBlMatcherFooterBar extends StatelessWidget {
  final int? activeFileId;
  final Map<String, dynamic>? matchResult;
  final bool isSavingDraft;
  final bool isSyncing;
  final VoidCallback onSaveDraft;
  final VoidCallback onApproveAndSync;

  const InvoiceBlMatcherFooterBar({
    super.key,
    required this.activeFileId,
    required this.matchResult,
    required this.isSavingDraft,
    required this.isSyncing,
    required this.onSaveDraft,
    required this.onApproveAndSync,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1150;
        final infoWidget = Row(
          children: [
            const Icon(Icons.sync_alt, color: AppTheme.cobalt, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.invoiceBlMatcherSyncFooterTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  Text(
                    activeFileId != null
                        ? l.invoiceBlMatcherSyncFooterDesc
                        : l.invoiceBlMatcherSyncFooterNoFile,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Export / Copy Match Report Button
            IdocUi.fit(AppButton(
              label: l.invoiceBlMatcherExportReportButton,
              icon: Icons.picture_as_pdf_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: matchResult == null
                  ? null
                  : () => InvoiceBlMatcherDialogHelper.showExportReportDialog(
                        context,
                        matchResult: matchResult!,
                        activeFileId: activeFileId,
                      ),
            )),
            // Save Draft Session Button
            IdocUi.fit(AppButton(
              label: context.l10n.idocASaveSessionDraftEmoji,
              icon: Icons.save_as_outlined,
              variant: AppButtonVariant.secondary,
              isLoading: isSavingDraft,
              onPressed: (activeFileId == null || isSavingDraft || isSyncing) ? null : onSaveDraft,
            )),
            // Certify & Final Save Button
            IdocUi.fit(AppButton(
              label: context.l10n.idocAApproveSaveFinalEmoji,
              icon: Icons.verified_rounded,
              variant: AppButtonVariant.success,
              isLoading: isSyncing,
              onPressed: (activeFileId == null || isSavingDraft || isSyncing) ? null : onApproveAndSync,
            )),
          ],
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderOf(context)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    infoWidget,
                    const SizedBox(height: 14),
                    actionButtons,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: infoWidget),
                    const SizedBox(width: 12),
                    Flexible(child: actionButtons),
                  ],
                ),
        );
      },
    );
  }
}

/// Dialog helpers for Certification Justification and Export Report.
class InvoiceBlMatcherDialogHelper {
  /// Asks for the justification required when certifying with discrepancies.
  static Future<String?> askCertifyJustification(BuildContext context) {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final l = ctx.l10n;
        return SelectionArea(
          child: AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(l.idocAConfirmNotMatchedTitle)),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.idocAConfirmNotMatchedBody),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('idocCertifyJustificationField'),
                      controller: ctrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l.idocAJustificationLabel,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? l.idocAJustificationRequired : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IdocUi.fit(AppButton(
                label: l.idocAReviewDiffs,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.pop(ctx),
              )),
              IdocUi.fit(AppButton(
                label: l.idocAConfirmFinal,
                variant: AppButtonVariant.danger,
                onPressed: () {
                  if (formKey.currentState?.validate() != true) return;
                  Navigator.pop(ctx, ctrl.text.trim());
                },
              )),
            ],
          ),
        );
      },
    ).whenComplete(ctrl.dispose);
  }

  /// Displays the Match Comparison Report dialog with Copy and FileSaveHelper export.
  static void showExportReportDialog(
    BuildContext context, {
    required Map<String, dynamic> matchResult,
    required int? activeFileId,
  }) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final score = matchResult['match_score_percentage'] ?? 0;
    final status = matchResult['overall_status'] ?? 'UNKNOWN';
    final isSafe = matchResult['is_safe_for_certification'] == true;
    final criticals = (matchResult['critical_discrepancies_count'] as num?)?.toInt() ?? 0;
    final warnings = (matchResult['warning_discrepancies_count'] as num?)?.toInt() ?? 0;
    final matrix = matchResult['comparison_matrix'] as List<dynamic>? ?? [];
    final correctionLetter = matchResult['correction_letter']?.toString() ?? '';

    final reportBuffer = StringBuffer();
    reportBuffer.writeln('===============================================================');
    reportBuffer.writeln('    ${l.invoiceBlMatcherReportDialogTitle}');
    reportBuffer.writeln('===============================================================');
    reportBuffer.writeln(l.invoiceBlMatcherReportMatchRatio(score));
    reportBuffer.writeln('${l.invoiceBlMatcherColMatchStatus} : $status');
    reportBuffer.writeln('${l.invoiceBlMatcherSyncFooterTitle} : ${isSafe ? l.reqBadgeYes : l.reqBadgeNo}');
    reportBuffer.writeln(l.invoiceBlMatcherCriticalCount(criticals));
    reportBuffer.writeln(l.invoiceBlMatcherWarningCount(warnings));
    reportBuffer.writeln('---------------------------------------------------------------');
    reportBuffer.writeln(
        '${l.invoiceBlMatcherColCheckItem}\t${l.invoiceBlMatcherColInvoiceValue}\t${l.invoiceBlMatcherColBlValue}\t${l.invoiceBlMatcherColMatchStatus}\t${l.invoiceBlMatcherColActionRequired}');
    for (final row in matrix) {
      final r = CodedItemText.localizeRow(row as Map, l, forExport: true);
      final checkItem = isArabic ? (r['field_name_ar'] ?? r['field_name_en'] ?? '') : (r['field_name_en'] ?? r['field_name_ar'] ?? '');
      final invVal = r['invoice_value'] ?? '—';
      final blVal = r['bl_value'] ?? '—';
      final matchStat = r['match_status'] == 'MATCH'
          ? l.invoiceBlMatcherStatusMatch
          : (r['match_status'] == 'MISMATCH_MINOR' ? l.invoiceBlMatcherStatusMinor : l.invoiceBlMatcherStatusMismatch);
      final details = r['details'] ?? '';
      reportBuffer.writeln('$checkItem\t$invVal\t$blVal\t$matchStat\t$details');
    }
    if (correctionLetter.isNotEmpty) {
      reportBuffer.writeln('---------------------------------------------------------------');
      reportBuffer.writeln('${l.invoiceBlMatcherCorrectionLetterTitle}:');
      reportBuffer.writeln(correctionLetter);
    }
    reportBuffer.writeln('===============================================================');

    final reportText = reportBuffer.toString();

    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.cobalt),
              const SizedBox(width: 10),
              Text(
                l.invoiceBlMatcherReportDialogTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: 700,
            height: 480,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l.invoiceBlMatcherReportMatchRatio(score)}  |  ${isSafe ? l.invoiceBlMatcherReportSafeStatus : l.invoiceBlMatcherReportUnsafeStatus}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSafe ? AppTheme.emerald : AppTheme.crimson,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        IdocUi.fit(AppButton(
                          label: l.invoiceBlMatcherCopyReportButton,
                          icon: Icons.copy,
                          variant: AppButtonVariant.ghost,
                          onPressed: () {
                            CopyHelper.copy(
                              ctx,
                              reportText,
                              customMessage: l.invoiceBlMatcherReportCopiedSuccess,
                            );
                          },
                        )),
                        IdocUi.fit(AppButton(
                          label: context.l10n.save,
                          icon: Icons.download_rounded,
                          variant: AppButtonVariant.secondary,
                          onPressed: () async {
                            await FileSaveHelper.exportAndSaveFile(
                              context: ctx,
                              bytes: utf8.encode(reportText),
                              stageName: 'Invoice BL Match Report',
                              importFileNameOrCode: activeFileId != null ? 'IMP-$activeFileId' : 'Report',
                              extension: 'txt',
                            );
                          },
                        )),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAltOf(ctx),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderOf(ctx)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        reportText,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IdocUi.fit(AppButton(
              label: l.invoiceBlMatcherCloseButton,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(ctx),
            )),
          ],
        ),
      ),
    );
  }
}
