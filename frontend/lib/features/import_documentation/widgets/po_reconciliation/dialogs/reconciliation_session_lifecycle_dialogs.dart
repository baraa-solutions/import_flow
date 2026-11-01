import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../models/po_reconciliation_session_model.dart';
import '../../../providers/import_documentation_provider.dart';
import '../../idoc_ui.dart';
import '../po_reconciliation_localizer.dart';

/// Dialogs for managing the lifecycle of PO reconciliation sessions (delete, overwrite, prompt existing).
class ReconciliationSessionLifecycleDialogs {
  static Widget buildDuplicateDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool?> confirmDeleteSession(BuildContext context, POReconciliationSessionModel sess) {
    final l = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.delete_forever_rounded, color: AppTheme.crimson, size: 28),
              const SizedBox(width: 10),
              Text(l.poRecHistoryDeleteConfirmTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            l.poRecHistoryDeleteConfirmContent(sess.sessionCode, sess.importFileCode ?? sess.importFileId.toString()),
            style: const TextStyle(fontSize: 13.5),
          ),
          actions: [
            IdocUi.fit(AppButton(
              label: l.cancel,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(ctx, false),
            )),
            IdocUi.fit(AppButton(
              label: l.poRecHistoryDeletePermanent,
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.pop(ctx, true),
            )),
          ],
        ),
      ),
    );
  }

  static Future<bool?> showExistingSessionConfirmDialog(
    BuildContext context, {
    required String statusLabel,
    required String updater,
    required String updatedTime,
    required String sessionCode,
  }) {
    final l = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 28),
              const SizedBox(width: 10),
              Text(context.l10n.idocANoticeASessionIsAlreadyRegistered,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            context.l10n.idocAExistingSessionUpdateBody(statusLabel, updater, updatedTime, sessionCode),
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            IdocUi.fit(AppButton(
              label: l.cancel,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(ctx, false),
            )),
            IdocUi.fit(AppButton(
              label: l.poRecUpdateExistingSessionButton,
              icon: Icons.update,
              variant: AppButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx, true),
            )),
          ],
        ),
      ),
    );
  }

  static Future<bool?> showExistingSessionNoticeDialog(
    BuildContext context,
    POReconciliationSessionModel existing, {
    required String statusLabel,
    required String updater,
    required String updatedTime,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.severityBackgroundOf(context, AppSeverity.warning),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.idocANoticeAReconciliationSessionIsAlready,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                ),
              ),
            ],
          ),
          content: Container(
            width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 520.0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.severityBackgroundOf(context, AppSeverity.warning).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.orange),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.idocAExistingSessionBody(statusLabel, updater, updatedTime),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.severityForegroundOf(context, AppSeverity.warning),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceOf(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderOf(context)),
                  ),
                  child: Column(
                    children: [
                      buildDuplicateDetailRow(context.l10n.idocASessionCode, existing.sessionCode),
                      if (existing.finalInvoiceNumber != null && existing.finalInvoiceNumber!.isNotEmpty)
                        buildDuplicateDetailRow(context.l10n.idocAFinalInvoiceNumber, existing.finalInvoiceNumber!),
                      buildDuplicateDetailRow(context.l10n.idocASessionStatus, statusLabel),
                      buildDuplicateDetailRow(context.l10n.idocAResponsibleUser, updater),
                      buildDuplicateDetailRow(context.l10n.idocASaveDateAndTime, updatedTime),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.idocAYouCanOpenAndContinueThe,
                  style: const TextStyle(fontSize: 12, color: AppTheme.charcoal, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            IdocUi.fit(AppButton(
              label: context.l10n.idocAClearSelection,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(ctx, false),
            )),
            IdocUi.fit(AppButton(
              label: context.l10n.idocAOpenAndContinueTheCurrentSession,
              icon: Icons.folder_open_rounded,
              variant: AppButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx, true),
            )),
          ],
        ),
      ),
    );
  }

  static Future<POReconciliationSessionModel?> promptExistingSessionIfAny({
    required BuildContext context,
    required WidgetRef ref,
    required int fileId,
  }) async {
    final sessionsList = ref.read(poReconciliationSessionsProvider).valueOrNull ?? [];
    final existing = sessionsList.where((s) => s.importFileId == fileId && s.isActive).firstOrNull;
    if (existing == null) return null;

    final isDraft = existing.overallStatus.toUpperCase() == 'DRAFT';
    final statusLabel =
        isDraft ? context.l10n.idocADraft3 : context.l10n.idocASavedApprovedStatus(existing.overallStatus);
    final updater =
        existing.certifiedBy?.isNotEmpty == true ? existing.certifiedBy! : context.l10n.idocADocumentsReviewer;
    final updatedTime =
        PoReconciliationLocalizer.formatSessionDate(context, existing.updatedAt ?? existing.createdAt);
    final shouldOpen = await showExistingSessionNoticeDialog(
      context,
      existing,
      statusLabel: statusLabel,
      updater: updater,
      updatedTime: updatedTime,
    );
    return (shouldOpen == true) ? existing : null;
  }

  static Future<void> deleteSessionWithConfirmation({
    required BuildContext context,
    required WidgetRef ref,
    required POReconciliationSessionModel sess,
  }) async {
    final confirm = await confirmDeleteSession(context, sess);
    if (confirm == true && sess.sessionId != null) {
      await ref.read(poReconciliationSessionsProvider.notifier).deleteSession(sess.sessionId!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.poRecHistoryDeletedSuccess(sess.sessionCode),
            severity: AppSeverity.success,
          ),
        );
      }
    }
  }
}
